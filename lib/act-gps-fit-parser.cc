/* -*- c-style: gnu -*-

   Copyright (c) 2013 John Harper <jsh@unfactored.org>

   Permission is hereby granted, free of charge, to any person
   obtaining a copy of this software and associated documentation files
   (the "Software"), to deal in the Software without restriction,
   including without limitation the rights to use, copy, modify, merge,
   publish, distribute, sublicense, and/or sell copies of the Software,
   and to permit persons to whom the Software is furnished to do so,
   subject to the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE. */

#include "act-gps-fit-parser.h"

#include "act-swap-bytes.h"

#include <algorithm>
#include <stddef.h>
#include <stdlib.h>
#include <time.h>

namespace act {
namespace gps {

struct fit_parser::message_field
{
  unsigned int field_type;
  unsigned int size;
  unsigned int base_type;

  message_field(unsigned int field_type_, unsigned int size_,
    unsigned int base_type_)
  : field_type (field_type_), size (size_), base_type (base_type_) {}
};

struct fit_parser::message_type
{
  bool big_endian;
  bool has_timestamp;
  unsigned int global_type;
  std::vector<message_field> fields;

  explicit message_type(bool big_endian_, unsigned int global_type_)
  : big_endian (big_endian_), has_timestamp(false),
    global_type (global_type_) {}
};

fit_parser::fit_parser(activity &dest)
: parser(dest),
  _file (0),
  _buf_base (0),
  _buf_idx (0),
  _buf_size (0)
{
  for (size_t i = 0; i < MAX_MESSAGE_TYPES; i++)
    _message_types[i] = nullptr;
}

fit_parser::~fit_parser()
{
  for (size_t i = 0; i < MAX_MESSAGE_TYPES; i++)
    delete _message_types[i];
}

void
fit_parser::parse_file(FILE *fh)
{
  _file = fh;

  _start_time = 0;

  _stopped = false;
  _stopped_timestamp = 0;
  _stopped_duration = 0;

  read_header ();
  read_data_records ();

  _file = nullptr;

  /* FIXME: ignoring CRC. */

  if (!had_error())
    {
      destination().update_points();
      destination().update_regions();
    }
}

/* pass null 'buf' pointer to seek forwards. */

bool
fit_parser::read_bytes(void *buf, size_t size)
{
  while (size > 0)
    {
      size_t n = std::min(size, _buf_size - _buf_idx);

      if (n > 0)
	{
	  if (buf)
	    {
	      memcpy(buf, _buf + _buf_idx, n);
	      buf = (uint8_t *) buf + n;
	    }

	  size = size - n;
	  _buf_idx += n;
	}

      if (_buf_idx == _buf_size)
	{
	  _buf_base += _buf_size;
	  _buf_size = fread(_buf, 1, sizeof(_buf), _file);
	  _buf_idx = 0;

	  if (_buf_size == 0)
	    {
	      memset(buf, 0, size);
	      return false;
	    }
	}
    }

  return true;
}

template<typename T> inline T
fit_parser::read(bool big_endian)
{
  T value;

  if (_buf_idx + sizeof(value) <= _buf_size)
    {
      memcpy(&value, _buf + _buf_idx, sizeof(value));
      _buf_idx += sizeof(value);
    }
  else
    read_bytes(&value, sizeof(value));

  if (!big_endian)
    value = swap_little_to_host(value);
  else
    value = swap_big_to_host(value);

  return value;
}

void
fit_parser::read_header()
{
  _header_size = read<uint8_t>();
  _protocol_version = read<uint8_t>();
  _profile_version = read<uint16_t>();
  _data_size = read<uint32_t>();

  char data_type[4];
  read_bytes(data_type, 4);

  if (data_type[0] != '.' || data_type[1] != 'F'
      || data_type[2] != 'I' || data_type[3] != 'T')
    {
      set_error();
    }

  /* Skip rest of header. Note, first two bytes may contain CRC? */

  read_bytes(nullptr, _header_size - 12);
}

void
fit_parser::read_data_records()
{
  size_t end = offset() + _data_size;

  while (!had_error() && offset() < end)
    {
      uint8_t header = read<uint8_t>();

      if ((header & (128|64)) == 64)
	{
	  /* definition message. */

	  unsigned int local_type = header & 15;

	  read_definition_message(local_type);
	}
      else
	{
	  /* data message. */

	  unsigned int local_type;
	  const message_type *def;
	  uint32_t timestamp = 0;

	  if ((header & 128) == 128)
	    {
	      /* compressed timestamp. */

	      local_type = (header >> 5) & 3;
	      def = _message_types[local_type];

	      if (!def)
		{
		  set_error();
		  return;
		}

	      if (def->has_timestamp)
		{
		  unsigned int time_offset = header & 31;
		  timestamp = (_previous_timestamp & 0xffffffe0U);
		  timestamp += time_offset;
		  if (time_offset < (_previous_timestamp & 31))
		    timestamp += 32;
		}
	    }
	  else
	    {
	      local_type = header & 15;

	      def = _message_types[local_type];

	      if (!def)
		{
		  set_error();
		  return;
		}

	      if (def->has_timestamp)
		{
		  timestamp = read<uint32_t>();
		  _previous_timestamp = timestamp;
		}
	    }

	  read_data_message(*def, timestamp);
	}
    }
}

void
fit_parser::read_definition_message(unsigned int local_type)
{
  read<uint8_t>();			/* reserved byte. */

  uint8_t architecture = read<uint8_t>();
  bool big_endian = architecture != 0;
  unsigned int global_type = read<uint16_t>(big_endian);
  size_t field_count = read<uint8_t>();

  message_type *def = new message_type(big_endian, global_type);

  for (size_t i = 0; i < field_count; i++)
    {
      unsigned int field_type = read<uint8_t>();
      unsigned int size = read<uint8_t>();
      unsigned int base_type = read<uint8_t>();

      /* Field 253 (timestamp) is handled as part of the message
	 header, to allow the compressed form. */

      if (field_type == 253)
	def->has_timestamp = true;
      else
	def->fields.push_back(message_field(field_type, size, base_type));
    }

  delete _message_types[local_type];
  _message_types[local_type] = def;
}

void
fit_parser::read_data_message(const message_type &def, uint32_t timestamp)
{
  /* Ignoring all fields not used by my FR210. */

  switch (def.global_type)
    {
    case 18:
      read_session_message(def, timestamp);
      break;

    case 19:
      read_lap_message(def, timestamp);
      break;

    case 20:
      read_record_message(def, timestamp);
      break;

    case 21:
      read_event_message(def, timestamp);
      break;

    case 0:				/* file_id */
    case 23:				/* device_info */
    case 34:				/* activity */
    case 49:				/* file_creator */
      /* fall through. */

    default:
      skip_message(def);
    }
}

namespace {

inline int32_t
check_invalid(int32_t value, int32_t invalid, int32_t replacement)
{
  return value != invalid ? value : replacement;
}

} // anonymous namespace

int32_t
fit_parser::read_field(const message_type &def,
		       const message_field &field, int32_t invalid_value)
{
  switch (field.base_type & 127)
    {
    case 0:				/* enum */
      return check_invalid(read<uint8_t>(), 0xff, invalid_value);

    case 1:				/* sint8 */
      return check_invalid(read<int8_t>(), 0x7f, invalid_value);

    case 2:				/* uint8 */
      return check_invalid(read<uint8_t>(), 0xff, invalid_value);

    case 3:				/* sint16 */
      return check_invalid(read<int16_t>(def.big_endian),
			   0x7fff, invalid_value);

    case 4:				/* uint16 */
      return check_invalid(read<uint16_t>(def.big_endian),
			   0xffff, invalid_value);

    case 5:				/* sint16 */
      return check_invalid(read<int32_t>(def.big_endian),
			   0x7fffffff, invalid_value);

    case 6:				/* uint16 */
      return check_invalid(read<uint32_t>(def.big_endian),
			   0xffffffff, invalid_value);

    case 7:				/* char[], null term. */
      set_error();
      return 0;

    case 8:				/* float */
    case 9:				/* double */
      set_error();
      return 0;

    case 10:				/* uint8z */
      return check_invalid(read<int8_t>(), 0, invalid_value);

    case 11:				/* uint16z */
      return check_invalid(read<uint16_t>(def.big_endian), 0, invalid_value);

    case 12:				/* uint32z */
      return check_invalid(read<uint32_t>(def.big_endian), 0, invalid_value);

    case 13:				/* uint8_t[] */
      set_error();
      return 0;

    default:
      set_error();
      return 0;
    }
}

void
fit_parser::skip_field (const message_field &field)
{
  switch (field.base_type & 127)
    {
    case 7:				/* char[], null term */
      while (!had_error())
	{
	  if (read<uint8_t>() == 0)
	    break;
	}
      break;

    case 13:				/* uint8_t[] */
      set_error();
      break;

    default:
      read_bytes(nullptr, field.size);
    }
}

namespace {

time_t
time_offset()
{
  struct tm tm = {0};

  // 1989-12-31 00:00:00 GMT

  tm.tm_mday = 31;
  tm.tm_mon = 11;
  tm.tm_year = 89;

  return timegm(&tm);
}

inline double
make_time(uint32_t timestamp)
{
  static time_t offset = time_offset();

  return timestamp + offset;
}

activity::sport_type
make_sport(int32_t value)
{
  switch (value)
    {
    case 1:
      return activity::sport_type::running;
    case 2:
      return activity::sport_type::cycling;
    case 5:
      return activity::sport_type::swimming;
    default:
      return activity::sport_type::unknown;
    }
}

inline double
make_lat_long(int32_t value)
{
  return value * (-180. / (1 << 31));
}

inline double
make_distance(uint32_t value)
{
  return value * .01;
}

inline double
make_speed(uint16_t value)
{
  return value * .001;
}

inline double
make_duration(uint32_t value)
{
  return value * .001;
}

inline double
make_altitude(uint16_t value)
{
  return value * .2 - 500;
}

inline float
make_cadence(uint16_t value)
{
  return value * 2;
}

inline float
make_training_effect(uint8_t value)
{
  return value * .1f;
}

inline float
make_stance_ratio(uint16_t value)
{
  return value * 1e-4f;
}

inline float
make_stance_time(uint16_t value)
{
  return value * 1e-4f;
}

inline float
make_vertical_oscillation(uint16_t value)
{
  return value * 1e-4f;
}

} // anonymous namespace

void
fit_parser::read_record_message(const message_type &def, uint32_t timestamp)
{
  activity::point p;

  double record_t = make_time(timestamp);

  if (_start_time == 0)
    _start_time = record_t;

  p.elapsed_time = record_t - _start_time;
  p.timer_time = ((!_stopped ? record_t : _stopped_timestamp)
		  - (_start_time + _stopped_duration));

  for (const auto &it : def.fields)
    {
      if (had_error())
	break;

      switch (it.field_type)
	{
	case 0:				/* position_lat */
	  p.location.latitude = make_lat_long(read_field(def, it));
	  if (p.location.latitude != 0)
	    destination().set_has_location(true);
	  break;

	case 1:				/* position_long */
	  p.location.longitude = make_lat_long(read_field(def, it));
	  if (p.location.longitude != 0)
	    destination().set_has_location(true);
	  break;

	case 2:				/* altitude */
	  p.altitude = make_altitude(read_field(def, it));
	  if (p.altitude != 0)
	    destination().set_has_altitude(true);
	  break;

	case 3:				/* heart_rate */
	  p.heart_rate = read_field(def, it);
	  if (p.heart_rate != 0)
	    destination().set_has_heart_rate(true);
	  break;

	case 4:				/* cadence */
	  p.cadence = make_cadence(read_field(def, it));
	  if (p.cadence != 0)
	    destination().set_has_cadence(true);
	  break;

	case 5:				/* distance */
	  p.distance = make_distance(read_field(def, it));
	  if (p.distance != 0)
	    destination().set_has_distance(true);
	  break;

	case 6:				/* speed */
	  p.speed = make_speed(read_field(def, it));
	  if (p.speed != 0)
	    destination().set_has_speed(true);
	  break;

	case 39:			/* vertical_oscillation */
	  p.vertical_oscillation
	    = make_vertical_oscillation(read_field(def, it));
	  if (p.vertical_oscillation != 0)
	    destination().set_has_dynamics(true);
	  break;

	case 40:			/* stance_time_percent */
	  p.stance_ratio = make_stance_ratio(read_field(def, it));
	  if (p.stance_ratio != 0)
	    destination().set_has_dynamics(true);
	  break;

	case 41:			/* stance_time */
	  p.stance_time = make_stance_time(read_field(def, it));
	  if (p.stance_time != 0)
	    destination().set_has_dynamics(true);
	  break;

	case 42:			/* activity_type */
	case 53:			/* unknown */
	  /* fall through. */

	default:
	  skip_field(it);
	}
    }

  destination().points().push_back(p);
}

void
fit_parser::read_event_message(const message_type &def, uint32_t timestamp)
{
  double time = make_time(timestamp);
  uint32_t data = 0;
  int event = -1;
  int event_type = -1;

  for (const auto &it : def.fields)
    {
      if (had_error())
	break;

      switch (it.field_type)
	{
	case 0:				/* event */
	  event = read_field(def, it);
	  break;

	case 1:				/* event_type */
	  event_type = read_field(def, it);
	  break;

	case 2:				/* data16 */
	case 3:				/* data */
	  data = read_field(def, it);
	  break;

	case 4:				/* event_group */
	  /* fall through. */

	default:
	  skip_field(it);
	}
    }

  switch (event)
    {
    case 0:				/* timer */
      if (event_type == 0)		/* event_type_start */
	{
	  if (_start_time == 0)
	    _start_time = time;

	  if (_stopped)
	    {
	      if (_stopped_timestamp != 0)
		_stopped_duration += time - _stopped_timestamp;

	      _stopped = false;
	    }
	}
      else if (event_type == 1		/* event_type_stop */
	       || event_type == 4)	/* event_type_stop_all */
	{
	  if (!_stopped)
	    {
	      _stopped_timestamp = time;
	      _stopped = true;
	    }
	}
      break;

    case 21:				/* recovery_hr */
      if (event_type == 3)		/* marker */
	destination().set_recovery_heart_rate(data, timestamp);
      break;

    case 37:				/* unknown */
    case 38:				/* unknown */
    case 39:				/* unknown */
      break;
    }
}

void
fit_parser::read_lap_message(const message_type &def, uint32_t timestamp)
{
  destination().laps().push_back(activity::lap());
  activity::lap &lap = destination().laps().back();

  double avg_cadence_frac = 0;
  double max_cadence_frac = 0;

  for (const auto &it : def.fields)
    {
      if (had_error())
	break;

      switch (it.field_type)
	{
	case 2:				/* start_time */
	  lap.start_elapsed_time
	    = make_time(read_field(def, it)) - _start_time;
	  break;

	case 7:				/* total_elapsed_time */
	  lap.total_elapsed_time = make_duration(read_field(def, it));
	  break;

	case 8:				/* total_timer_time */
	  lap.total_duration = make_duration(read_field(def, it));
	  break;

	case 9:				/* total_distance */
	  lap.total_distance = make_distance(read_field(def, it));
	  break;

	case 13:			/* avg_speed */
	  lap.avg_speed = make_speed(read_field(def, it));
	  break;

	case 14:			/* max_speed */
	  lap.max_speed = make_speed(read_field(def, it));
	  break;

	case 11:			/* total_calories */
	  lap.total_calories = read_field(def, it);
	  break;

	case 15:			/* avg_heart_rate */
	  lap.avg_heart_rate = read_field(def, it);
	  break;

	case 16:			/* max_heart_rate */
	  lap.max_heart_rate = read_field(def, it);
	  break;

	case 17:			/* avg_cadence */
	  lap.avg_cadence = make_cadence(read_field(def, it));
	  break;

	case 18:			/* max_cadence */
	  lap.max_cadence = make_cadence(read_field(def, it));
	  break;

	case 21:			/* total_ascent */
	  lap.total_ascent = read_field(def, it);
	  break;

	case 22:			/* total_descent */
	  lap.total_descent = read_field(def, it);
	  break;

	case 77:			/* avg_vertical_oscillation */
	  lap.avg_vertical_oscillation
	    = make_vertical_oscillation(read_field(def, it));
	  break;

	case 78:			/* avg_stance_time_percent */
	  lap.avg_stance_ratio = make_stance_ratio(read_field(def, it));
	  break;

	case 79:			/* avg_stance_time */
	  lap.avg_stance_time = make_stance_time(read_field(def, it));
	  break;

	case 80:			/* avg_fractional_cadence */
	  avg_cadence_frac = read_field(def, it) * (1/128.);
	  break;

	case 81:			/* max_fractional_cadence */
	  max_cadence_frac = read_field(def, it) * (1/128.);
	  break;

	case 10:			/* total_strides */
	case 82:			/* total_fractional_cycles(invalid) */
	  /* fall through. */

	default:
	  skip_field(it);
	}
    }

  if (lap.avg_cadence != 0)
    lap.avg_cadence += avg_cadence_frac;
  if (lap.max_cadence != 0)
    lap.max_cadence += max_cadence_frac;
}

void
fit_parser::read_session_message(const message_type &def, uint32_t timestamp)
{
  activity &d = destination();

  double avg_cadence_frac = 0;
  double max_cadence_frac = 0;

  for (const auto &it : def.fields)
    {
      if (had_error())
	break;

      switch (it.field_type)
	{
	case 2:				/* start_time */
	  d.set_start_time(make_time(read_field(def, it)));
	  break;

	case 5:				/* sport */
	  d.set_sport(make_sport(read_field(def, it)));
	  break;

	case 7:				/* total_elapsed_time */
	  d.set_total_elapsed_time(make_duration(read_field(def, it)));
	  break;

	case 8:				/* total_timer_time */
	  d.set_total_duration(make_duration(read_field(def, it)));
	  break;

	case 9:				/* total_distance */
	  d.set_total_distance(make_distance(read_field(def, it)));
	  break;

	case 11:			/* total_calories */
	  d.set_total_calories(read_field(def, it));
	  break;

	case 14:			/* avg_speed */
	  d.set_avg_speed(make_speed(read_field(def, it)));
	  break;

	case 15:			/* max_speed */
	  d.set_max_speed(make_speed(read_field(def, it)));
	  break;

	case 16:			/* avg_heart_rate */
	  d.set_avg_heart_rate(read_field(def, it));
	  break;

	case 17:			/* max_heart_rate */
	  d.set_max_heart_rate(read_field(def, it));
	  break;

	case 18:			/* avg_cadence */
	  d.set_avg_cadence(make_cadence(read_field(def, it)));
	  break;

	case 19:			/* max_cadence */
	  d.set_max_cadence(make_cadence(read_field(def, it)));
	  break;

	case 22:			/* total_ascent */
	  d.set_total_ascent(read_field(def, it));
	  break;

	case 23:			/* total_descent */
	  d.set_total_descent(read_field(def, it));
	  break;

	case 24:			/* total_training_effect */
	  d.set_training_effect(make_training_effect(read_field(def, it)));
	  break;

	case 89: {			/* avg_vertical_oscillation */
	  double x = make_vertical_oscillation(read_field(def, it));
	  d.set_avg_vertical_oscillation(x);
	  break; }

	case 90:			/* avg_stance_time_percent */
	  d.set_avg_stance_ratio(make_stance_ratio(read_field(def, it)));
	  break;

	case 91:			/* avg_stance_time */
	  d.set_avg_stance_time(make_stance_time(read_field(def, it)));
	  break;

	case 92:			/* avg_fractional_cadence */
	  avg_cadence_frac = read_field(def, it) * (1/128.);
	  break;

	case 93:			/* max_fractional_cadence */
	  max_cadence_frac = read_field(def, it) * (1/128.);
	  break;

	case 81:			/* unknown */
	case 94:			/* total_fractional_cycles(invalid) */
	  /* fall through. */

	default:
	  skip_field(it);
	}
    }

  if (d.avg_cadence() != 0)
    d.set_avg_cadence(d.avg_cadence() + avg_cadence_frac);
  if (d.max_cadence() != 0)
    d.set_max_cadence(d.max_cadence() + max_cadence_frac);
}

void
fit_parser::skip_message(const message_type &def)
{
  for (const auto &it : def.fields)
    {
      skip_field(it);
    }
}

} // namespace gps
} // namespace act
