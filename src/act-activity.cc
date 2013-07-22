// -*- c-style: gnu -*-

#include "act-activity.h"

#include "act-config.h"
#include "act-format.h"
#include "act-util.h"

#include <xlocale.h>

namespace act {

activity::activity(std::shared_ptr<activity_storage> storage)
: _storage(storage),
  _invalid_groups(group_all)
{
}

void
activity::read_cached_values(unsigned int groups) const
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
      _distance_unit = unit_miles;
      _speed = 0;
      _speed_unit = unit_seconds_per_mile;
      _max_speed = 0;
      _max_speed_unit = unit_seconds_per_mile;
    }

  if (groups & group_physiological)
    {
      _resting_hr = 0;
      _average_hr = 0;
      _max_hr = 0;
      _calories = 0;
      _weight = 0;
      _weight_unit = unit_kilogrammes;
    }

  if (groups & group_other)
    {
      _effort = 0;
      _quality = 0;
      _temperature = 0;
      _temperature_unit = unit_celsius;
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

      if (_speed == 0 && _duration != 0 && _distance != 0)
	_speed = _distance / _duration;

      if (_date == 0 || _duration == 0 || _distance == 0 || _speed == 0)
	use_gps = true;
    }

  if (groups & group_physiological)
    {
      if (const std::string *s = field_ptr("resting-hr"))
	parse_number(*s, &_resting_hr);
      if (const std::string *s = field_ptr("average-hr"))
	parse_number(*s, &_average_hr);
      if (const std::string *s = field_ptr("max-hr"))
	parse_number(*s, &_max_hr);

      if (const std::string *s = field_ptr("calories"))
	parse_number(*s, &_calories);
      if (const std::string *s = field_ptr("Weight"))
	parse_weight(*s, &_weight, &_weight_unit);

      if (_resting_hr == 0 || _average_hr == 0 || _max_hr == 0 || _calories == 0)
	use_gps = true;
    }

  if (groups & group_other)
    {
      if (const std::string *s = field_ptr("effort"))
	parse_fraction(*s, &_effort);
      if (const std::string *s = field_ptr("quality"))
	parse_fraction(*s, &_quality);

      if (const std::string *s = field_ptr("temperature"))
	parse_temperature(*s, &_temperature, &_temperature_unit);

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
		_date = (time_t) data->time();
	      if (_duration == 0)
		_duration = data->duration();
	      if (_distance == 0)
		_distance = data->distance();
	      if (_speed == 0)
		{
		  _speed = data->avg_speed();
		  if (data->sport() == gps::activity::sport_cycling)
		    _speed_unit = unit_miles_per_hour;
		}
	      if (_max_speed == 0)
		{
		  _max_speed = data->max_speed();
		  _max_speed_unit = _speed_unit;
		}
	    }

	  if (groups & group_other)
	    {
	      if (_average_hr == 0)
		_average_hr = data->avg_heart_rate();
	      if (_max_hr == 0)
		_max_hr = data->max_heart_rate();
	      if (_calories == 0)
		_calories = data->calories();
	    }
	}
    }
}

double
activity::field_value(field_id id) const
{
  switch (id)
    {
    case field_date:
      return date();
    case field_duration:
      return duration();
    case field_distance:
      return distance();
    case field_speed:
    case field_pace:
      return speed();
    case field_max_speed:
    case field_max_pace:
      return max_speed();
    case field_effort:
      return effort();
    case field_quality:
      return quality();
    case field_resting_hr:
      return resting_hr();
    case field_average_hr:
      return average_hr();
    case field_max_hr:
      return max_hr();
    case field_calories:
      return calories();
    case field_weight:
      return weight();
    case field_temperature:
      return temperature();
    default:
      return 0;
    }
}

const std::vector<std::string> *
activity::field_keywords_ptr(field_id id) const
{
  switch (id)
    {
    case field_equipment:
      return &equipment();
    case field_weather:
      return &weather();
    case field_keywords:
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
    case field_date:
      return unit_seconds;
    case field_distance:
      return distance_unit();
    case field_speed:
    case field_pace:
      return speed_unit();
    case field_max_speed:
    case field_max_pace:
      return max_speed_unit();
    case field_weight:
      return weight_unit();
    case field_temperature:
      return temperature_unit();
    default:
      return unit_unknown;
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
  return _duration;
}

double
activity::distance() const
{
  validate_cached_values(group_timing);
  return _distance;
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
  return _speed;
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
  strftime(buf, sizeof(buf), "%Y/%m/%Y-%m-%d-%H-%M.txt", &tm);
  filename.append(buf);

  return make_path(filename.c_str());
}

namespace {

unsigned int
convert_hexdigit(int c)
{
  if (c >= '0' && c <= '9')
    return c - '0';
  else if (c >= 'A' && c <= 'F')
    return 10 + c - 'A';
  else if (c >= 'a' && c <= 'f')
    return 10 + c - 'a';
  else
    return 0;
}

void
print_indented_string(const char *str, size_t len, FILE *fh)
{
  const char *ptr = str;

  while (ptr < str + len)
    {
      const char *eol = strchr(ptr, '\n');
      if (!eol)
	break;

      if (eol > str + len)
	eol = str + len;

      fputs("    ", fh);
      fwrite(ptr, 1, eol - ptr, fh);
      fputc('\n', fh);

      ptr = eol + 1;
    }
}

} // anonymous namespace

void
activity::printf(FILE *fh, const char *format) const
{
  while (*format != 0)
    {
      if (const char *ptr = strchr(format, '%'))
	{
	  if (ptr > format)
	    fwrite(format, 1, ptr - format, fh);

	  ptr++;
	  switch (*ptr++)
	    {
	    case 'n':
	      fputc('\n', fh);
	      break;

	    case '%':
	      fputc('\n', fh);
	      break;

	    case 'x':
	      if (ptr[0] != 0 && ptr[1] != 0)
		{
		  int c0 = convert_hexdigit(ptr[0]);
		  int c1 = convert_hexdigit(ptr[1]);
		  fputc((c0 << 4) | c1, fh);
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

		  print_expansion(fh, token, arg);
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

		  if (const std::string *str = field_ptr(std::string(token)))
		    fprintf(fh, "%s: %s\n", token, str->c_str());
		}
	      ptr = end ? end + 1 : ptr + strlen(ptr);
	      break; }
	    }
	  format = ptr;
	}
      else
	{
	  fputs(format, fh);
	  break;
	}
    }
}

void
activity::print_expansion(FILE *fh, const char *name, const char *arg) const
{
  if (strcasecmp(name, "all-fields") == 0)
    {
      for (const auto &it : *_storage)
	fprintf(fh, "%s: %s\n", it.first.c_str(), it.second.c_str());
    }
  else if (strcasecmp(name, "body") == 0)
    {
      const char *body = this->body().c_str();

      if (!arg || strcasecmp(arg, "all") == 0)
	{
	  print_indented_string(body, this->body().size(), fh);
	}
      else if (strcasecmp(arg, "first-line") == 0)
	{
	  const char *end = strchr(body, '\n');
	  size_t len;
	  if (!end)
	    len = strlen(body);
	  else
	    len = end - body;
	  fwrite(body, 1, len, fh);
	}
      else if (strcasecmp(arg, "first-para") == 0)
	{
	  const char *end = strstr(body, "\n\n");
	  size_t len;
	  if (!end)
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

      fputs(buf, fh);
    }
  else if (strcasecmp(name, "relative-date") == 0)
    {
    }
  else if (strcasecmp(name, "activity-data") == 0)
    {
    }
  else if (strcasecmp(name, "activity-path") == 0)
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
	case type_string:
	  str = field_ptr(std::string(name));
	  break;

	case type_date:
	  abort();

	  /* FIXME: add a way to specify custom unit conversions,
	     precision specifiers, etc. */

	case type_duration:
	case type_number:
	case type_distance:
	case type_pace:
	case type_speed:
	case type_temperature:
	case type_fraction:
	case type_weight: {
	  double value = field_value(id);
	  unit_type unit = field_unit(id);
	  format_value(tem, type, value, unit);
	  str = &tem;
	  break; }

	case type_keywords:
	  if (const std::vector<std::string>
	      *keys = field_keywords_ptr(id))
	    {
	      format_keywords(tem, *keys);
	      str = &tem;
	    }
	  break;
	}

      if (str)
	fwrite(str->c_str(), 1, str->size(), fh);
    }
}

const gps::activity *
activity::gps_data() const
{
  if (!_gps_data)
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
