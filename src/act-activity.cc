// -*- c-style: gnu -*-

#include "act-activity.h"

#include "act-config.h"
#include "act-format.h"
#include "act-util.h"

#include <math.h>
#include <xlocale.h>

namespace act {

activity::activity(activity_storage_ref storage)
: _storage(storage),
  _invalid_groups(group_all),
  _seed(0)
{
}

void
activity::validate_cached_values(unsigned int groups) const
{
  if (_seed != _storage->seed())
    _invalid_groups |= group_all;

  if (_invalid_groups & groups)
    {
      groups = groups & _invalid_groups;

      if (groups == 0)
	return;

      _invalid_groups &= ~groups;

      if (groups & group_timing)
	{
	  _date = 0;
	  _duration = 0;
	  _distance = 0;
	  _distance_unit = unit_type::miles;
	  _speed = 0;
	  _speed_unit = unit_type::seconds_per_mile;
	  _max_speed = 0;
	  _max_speed_unit = unit_type::seconds_per_mile;
	}

      if (groups & group_physiological)
	{
	  _resting_hr = 0;
	  _average_hr = 0;
	  _max_hr = 0;
	  _calories = 0;
	  _weight = 0;
	  _weight_unit = unit_type::kilogrammes;
	}

      if (groups & group_other)
	{
	  _effort = 0;
	  _quality = 0;
	  _points = 0;
	  _temperature = 0;
	  _temperature_unit = unit_type::celsius;
	  _dew_point = 0;
	  _dew_point_unit = unit_type::celsius;
	  _equipment.clear();
	  _weather.clear();
	  _keywords.clear();
	}

      // Pull values out of the file

      bool use_gps = false;

      if (groups & group_timing)
	{
	  if (const std::string *s = field_ptr("date"))
	    parse_date_time(*s, &_date, nullptr);

	  if (const std::string *s = field_ptr("duration"))
	    parse_duration(*s, &_duration);

	  if (const std::string *s = field_ptr("distance"))
	    parse_distance(*s, &_distance, &_distance_unit);

	  if (const std::string *s = field_ptr("pace"))
	    parse_pace(*s, &_speed, &_speed_unit);
	  else if (const std::string *s = field_ptr("speed"))
	    parse_speed(*s, &_speed, &_speed_unit);

	  if (const std::string *s = field_ptr("max-pace"))
	    parse_pace(*s, &_max_speed, &_max_speed_unit);
	  else if (const std::string *s = field_ptr("max-speed"))
	    parse_speed(*s, &_max_speed, &_max_speed_unit);

	  if (_date == 0)
	    use_gps = true;

	  if (_duration != 0 + _distance != 0 + _speed != 0 < 2)
	    use_gps = true;
	}

      if (groups & group_physiological)
	{
	  if (const std::string *s = field_ptr("resting-hr"))
	    parse_heart_rate(*s, &_resting_hr, nullptr);
	  if (const std::string *s = field_ptr("average-hr"))
	    parse_heart_rate(*s, &_average_hr, nullptr);
	  if (const std::string *s = field_ptr("max-hr"))
	    parse_heart_rate(*s, &_max_hr, nullptr);

	  if (const std::string *s = field_ptr("calories"))
	    parse_number(*s, &_calories);
	  if (const std::string *s = field_ptr("Weight"))
	    parse_weight(*s, &_weight, &_weight_unit);

	  if (_resting_hr == 0 || _average_hr == 0
	      || _max_hr == 0 || _calories == 0)
	    use_gps = true;
	}

      if (groups & group_other)
	{
	  if (const std::string *s = field_ptr("effort"))
	    parse_fraction(*s, &_effort);
	  if (const std::string *s = field_ptr("quality"))
	    parse_fraction(*s, &_quality);
	  if (const std::string *s = field_ptr("points"))
	    parse_number(*s, &_points);

	  if (const std::string *s = field_ptr("temperature"))
	    parse_temperature(*s, &_temperature, &_temperature_unit);

	  if (const std::string *s = field_ptr("dew-point"))
	    parse_temperature(*s, &_dew_point, &_dew_point_unit);

	  if (const std::string *s = field_ptr("equipment"))
	    parse_keywords(*s, &_equipment);
	  if (const std::string *s = field_ptr("weather"))
	    parse_keywords(*s, &_weather);
	  if (const std::string *s = field_ptr("keywords"))
	    parse_keywords(*s, &_keywords);
	}

      // Look in GPS file for other missing values

      if (use_gps)
	{
	  if (const gps::activity *data = gps_data())
	    {
	      if (groups & group_timing)
		{
		  if (_date == 0)
		    _date = (time_t) data->start_time();
		  if (_duration == 0)
		    _duration = data->total_duration();
		  if (_distance == 0)
		    _distance = data->total_distance();
		  if (_speed == 0)
		    {
		      _speed = data->avg_speed();
		      if (data->sport() == gps::activity::sport_type::cycling)
			_speed_unit = unit_type::miles_per_hour;
		    }
		  if (_max_speed == 0)
		    {
		      _max_speed = data->max_speed();
		      _max_speed_unit = _speed_unit;
		    }
		}

	      if (groups & group_physiological)
		{
		  if (_average_hr == 0)
		    _average_hr = data->avg_heart_rate();
		  if (_max_hr == 0)
		    _max_hr = data->max_heart_rate();
		  if (_calories == 0)
		    _calories = data->total_calories();
		}
	    }
	}
    }
}

double
activity::field_value(field_id id) const
{
  switch (id)
    {
    case field_id::date:
      return date();
    case field_id::duration:
      return duration();
    case field_id::distance:
      return distance();
    case field_id::speed:
    case field_id::pace:
      return speed();
    case field_id::max_speed:
    case field_id::max_pace:
      return max_speed();
    case field_id::effort:
      return effort();
    case field_id::quality:
      return quality();
    case field_id::resting_hr:
      return resting_hr();
    case field_id::average_hr:
      return average_hr();
    case field_id::max_hr:
      return max_hr();
    case field_id::calories:
      return calories();
    case field_id::weight:
      return weight();
    case field_id::temperature:
      return temperature();
    case field_id::dew_point:
      return dew_point();
    case field_id::vdot:
      return vdot();
    case field_id::points:
      return points();
    default:
      return 0;
    }
}

const std::vector<std::string> *
activity::field_keywords_ptr(field_id id) const
{
  switch (id)
    {
    case field_id::equipment:
      return &equipment();
    case field_id::weather:
      return &weather();
    case field_id::keywords:
      return &keywords();
    default:
      return nullptr;
    }
}

unit_type
activity::field_unit(field_id id) const
{
  switch (id)
    {
    case field_id::date:
      return unit_type::seconds;
    case field_id::distance:
      return distance_unit();
    case field_id::speed:
    case field_id::pace:
      return speed_unit();
    case field_id::max_speed:
    case field_id::max_pace:
      return max_speed_unit();
    case field_id::weight:
      return weight_unit();
    case field_id::temperature:
      return temperature_unit();
    case field_id::dew_point:
      return dew_point_unit();
    default:
      return unit_type::unknown;
    }
}

time_t
activity::date() const
{
  validate_cached_values(group_timing);
  return _date;
}

double
activity::duration() const
{
  validate_cached_values(group_timing);

  if (_duration != 0)
    return _duration;
  else if (_distance != 0 && _speed != 0)
    return _distance / _speed;
  else
    return 0;
}

double
activity::distance() const
{
  validate_cached_values(group_timing);

  if (_distance != 0)
    return _distance;
  else if (_duration != 0 && _speed != 0)
    return _speed * _duration;
  else
    return 0;
}

unit_type
activity::distance_unit() const
{
  validate_cached_values(group_timing);
  return _distance_unit;
}

double
activity::speed() const
{
  validate_cached_values(group_timing);

  // Even if speed was explicitly specified, ignore it if duration and
  // distance are also known. Only use speed value in calculations if
  // one of the other two values is missing.

  if (_speed != 0 && (_duration == 0 || _distance == 0))
    return _speed;
  else if (_duration != 0 && _distance != 0)
    return _distance / _duration;
  else
    return 0;
}

unit_type
activity::speed_unit() const
{
  validate_cached_values(group_timing);
  return _speed_unit;
}

double
activity::max_speed() const
{
  validate_cached_values(group_timing);
  return _max_speed;
}

unit_type
activity::max_speed_unit() const
{
  validate_cached_values(group_timing);
  return _max_speed_unit;
}

double
activity::effort() const
{
  validate_cached_values(group_other);
  return _effort;
}

double
activity::quality() const
{
  validate_cached_values(group_other);
  return _quality;
}

double
activity::points() const
{
  validate_cached_values(group_other);
  return _points;
}

double
activity::resting_hr() const
{
  validate_cached_values(group_physiological);
  return _resting_hr;
}

double
activity::average_hr() const
{
  validate_cached_values(group_physiological);
  return _average_hr;
}

double
activity::max_hr() const
{
  validate_cached_values(group_physiological);
  return _max_hr;
}

double
activity::calories() const
{
  validate_cached_values(group_physiological);
  return _calories;
}

double
activity::weight() const
{
  validate_cached_values(group_physiological);
  return _weight;
}

unit_type
activity::weight_unit() const
{
  validate_cached_values(group_physiological);
  return _weight_unit;
}

const std::vector<std::string> &
activity::equipment() const
{
  validate_cached_values(group_other);
  return _equipment;
}

double
activity::temperature() const
{
  validate_cached_values(group_other);
  return _temperature;
}

unit_type
activity::temperature_unit() const
{
  validate_cached_values(group_other);
  return _temperature_unit;
}

double
activity::dew_point() const
{
  validate_cached_values(group_other);
  return _dew_point;
}

unit_type
activity::dew_point_unit() const
{
  validate_cached_values(group_other);
  return _dew_point_unit;
}

const std::vector<std::string> &
activity::weather() const
{
  validate_cached_values(group_other);
  return _weather;
}

const std::vector<std::string> &
activity::keywords() const
{
  validate_cached_values(group_other);
  return _keywords;
}

double
activity::vdot() const
{
  double time = duration() / 60;
  double velocity = speed() * 60;

  if (time > 0 && velocity > 0)
    {
      double percent_max = (0.8 + 0.1894393 * exp(-0.012778 * time)
			    + 0.2989558 * exp(-0.1932605 * time));
      double vo2 = -4.60 + 0.182258 * velocity + 0.000104 * velocity*velocity;
      double vdot = vo2 / percent_max;
      return round(vdot*10) * .1;
    }
  else
    return 0;
}

bool
activity::make_filename(std::string &filename) const
{
  time_t d = date();
  if (d == 0)
    return false;

  struct tm tm = {0};
  localtime_r(&d, &tm);

  filename = shared_config().activity_dir();
  if (filename.size() > 1 && filename[filename.size() - 1] != '/')
    filename.push_back('/');

  char buf[256];
  strftime(buf, sizeof(buf), "%Y/%m/%d-%H%M.txt", &tm);
  filename.append(buf);

  return make_path(filename.c_str());
}

void
activity::printf(const char *format) const
{
  while (*format != 0)
    {
      if (const char *ptr = strchr(format, '%'))
	{
	  if (ptr > format)
	    fwrite(format, 1, ptr - format, stdout);

	  ptr++;

	  bool left_relative = false;
	  if (ptr[0] == '-' && isdigit(ptr[1]))
	    left_relative = true, ptr++;

	  int field_width = 0;
	  while (isdigit(*ptr))
	    field_width = field_width * 10 + (*ptr++ - '0');

	  switch (*ptr++)
	    {
	    case 'n':
	      fputc('\n', stdout);
	      break;

	    case 't':
	      fputc('\t', stdout);
	      break;

	    case '%':
	      fputc('\n', stdout);
	      break;

	    case 'x':
	      if (ptr[0] != 0 && ptr[1] != 0)
		{
		  int c0 = convert_hexdigit(ptr[0]);
		  int c1 = convert_hexdigit(ptr[1]);
		  fputc((c0 << 4) | c1, stdout);
		}
	      break;

	    case '{': {
	      const char *end = strchr(ptr, '}');
	      char token[128];
	      if (end && end - ptr < sizeof(token)-1)
		{
		  memcpy(token, ptr, end - ptr);
		  token[end - ptr] = 0;

		  char *arg = strchr(token, ':');
		  if (arg)
		    *arg++ = 0;

		  print_expansion(stdout, token, arg, !left_relative
				  ? field_width : -field_width);
		}
	      ptr = end ? end + 1 : ptr + strlen(ptr);
	      break; }

	    case '[': {
	      const char *end = strchr(ptr, ']');
	      char token[128];
	      if (end && end - ptr < sizeof(token)-1)
		{
		  memcpy(token, ptr, end - ptr);
		  token[end - ptr] = 0;

		  char *arg = strchr(token, ':');
		  if (arg)
		    *arg++ = 0;

		  print_field(stdout, token, arg);
		}
	      ptr = end ? end + 1 : ptr + strlen(ptr);
	      break; }
	    }
	  format = ptr;
	}
      else
	{
	  fputs(format, stdout);
	  break;
	}
    }
}

void
activity::print_expansion(FILE *fh, const char *name,
			  const char *arg, int field_width) const
{
  if (strcasecmp(name, "body") == 0)
    {
      const char *body = this->body().c_str();

      if (arg == nullptr || strcasecmp(arg, "all") == 0)
	{
	  print_indented_string(body, this->body().size(), fh);
	}
      else if (strcasecmp(arg, "first-line") == 0)
	{
	  const char *end = strchr(body, '\n');
	  size_t len;
	  if (end == nullptr)
	    len = strlen(body);
	  else
	    len = end - body;
	  fwrite(body, 1, len, fh);
	}
      else if (strcasecmp(arg, "first-para") == 0)
	{
	  const char *end = strstr(body, "\n\n");
	  size_t len;
	  if (end == nullptr)
	    len = strlen(body);
	  else
	    len = end - body;
	  print_indented_string(body, len, fh);
	}
    }
  else if (strcasecmp(name, "date") == 0)
    {
      if (arg == nullptr)
	arg = "%F %r %z";

      time_t d = date();
      struct tm tm = {0};
      localtime_r(&d, &tm);

      char buf[1024];
      strftime(buf, sizeof(buf), arg, &tm);

      if (field_width == 0)
	fputs(buf, fh);
      else
	fprintf(fh, "%*s", field_width, buf);
    }
  else if (strcasecmp(name, "relative-date") == 0)
    {
    }
  else
    {
      field_id id = lookup_field_id(name);
      field_data_type type = lookup_field_data_type(id);

      const std::string *str = nullptr;
      std::string tem;

      switch (type)
	{
	case field_data_type::string:
	  str = field_ptr(std::string(name));
	  break;

	case field_data_type::date:
	  abort();

	  /* FIXME: add a way to specify custom unit conversions,
	     precision specifiers, etc. */

	case field_data_type::duration:
	case field_data_type::number:
	case field_data_type::distance:
	case field_data_type::pace:
	case field_data_type::speed:
	case field_data_type::temperature:
	case field_data_type::fraction:
	case field_data_type::weight:
	case field_data_type::heart_rate: {
	  double value = field_value(id);
	  unit_type unit = field_unit(id);
	  format_value(tem, type, value, unit);
	  str = &tem;
	  break; }

	case field_data_type::keywords:
	  if (const std::vector<std::string>
	      *keys = field_keywords_ptr(id))
	    {
	      format_keywords(tem, *keys);
	      str = &tem;
	    }
	  break;
	}

      if (str)
	{
	  if (field_width == 0)
	    fwrite(str->c_str(), 1, str->size(), fh);
	  else
	    fprintf(fh, "%*s", field_width, str->c_str());
	}
    }
}

void
activity::print_field(FILE *fh, const char *field, const char *arg) const
{
  if (const std::string *str = field_ptr(std::string(field)))
    {
      field_id id = lookup_field_id(field);
      std::string tem(*str);
      canonicalize_field_string(lookup_field_data_type(id), tem);
      fprintf(stdout, "%s: %s\n", field, tem.c_str());
    }
  else if (strcasecmp(field, "header") == 0)
    {
      for (const auto &it : *_storage)
	{
	  field_id id = lookup_field_id(it.first.c_str());
	  std::string tem(it.second);
	  canonicalize_field_string(lookup_field_data_type(id), tem);
	  fprintf(stdout, "%s: %s\n", it.first.c_str(), tem.c_str());
	}
    }
  else if (strcasecmp(field, "body") == 0)
    {
      print_indented_string(body().c_str(), body().size(), fh);
    }
  else if (strcasecmp(field, "laps") == 0)
    {
      if (const gps::activity *a = gps_data())
	a->print_laps(fh);
    }
}

const gps::activity *
activity::gps_data() const
{
  if (_gps_data == nullptr)
    {
      if (const std::string *str = field_ptr("gps-file"))
	{
	  std::string path(*str);
	  if (shared_config().find_gps_file(path))
	    {
	      std::unique_ptr<gps::activity> a (new gps::activity);
	      if (a->read_file(path.c_str()))
		{
		  using std::swap;
		  swap(_gps_data, a);
		}
	    }
	}
    }

  return _gps_data.get();
}

} // namespace act
