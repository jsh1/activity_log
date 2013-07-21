// -*- c-style: gnu -*-

#include "act-activity.h"

#include "act-config.h"
#include "act-util.h"

#include <xlocale.h>

namespace act {

activity::field_id
activity::lookup_field_id(const char *str)
{
  switch (tolower_l(str[0], nullptr))
    {
    case 'a':
      if (strcasecmp(str, "activity") == 0)
	return field_activity;
      else if (strcasecmp(str, "average_hr") == 0)
	return field_average_hr;
      break;

    case 'c':
      if (strcasecmp(str, "calories") == 0)
	return field_calories;
      else if (strcasecmp(str, "course") == 0)
	return field_course;
      break;

    case 'd':
      if (strcasecmp(str, "date") == 0)
	return field_date;
      else if (strcasecmp(str, "distance") == 0)
	return field_distance;
      else if (strcasecmp(str, "duration") == 0)
	return field_duration;
      break;

    case 'e':
      if (strcasecmp(str, "effort") == 0)
	return field_effort;
      else if (strcasecmp(str, "equipment") == 0)
	return field_equipment;
      break;

    case 'g':
      if (strcasecmp(str, "gps-file") == 0)
	return field_gps_file;
      break;

    case 'k':
      if (strcasecmp(str, "keywords") == 0)
	return field_keywords;
      break;

    case 'm':
      if (strcasecmp(str, "max-hr") == 0)
	return field_max_hr;
      else if (strcasecmp(str, "max-pace") == 0)
	return field_max_pace;
      else if (strcasecmp(str, "max-speed") == 0)
	return field_max_speed;
      break;

    case 'p':
      if (strcasecmp(str, "pace") == 0)
	return field_pace;
      break;

    case 'q':
      if (strcasecmp(str, "quality") == 0)
	return field_quality;
      break;

    case 'r':
      if (strcasecmp(str, "resting-hr") == 0)
	return field_resting_hr;
      break;

    case 't':
      if (strcasecmp(str, "temperature") == 0)
	return field_temperature;
      else if (strcasecmp(str, "type") == 0)
	return field_type;
      break;

    case 'w':
      if (strcasecmp(str, "weather") == 0)
	return field_weather;
      else if (strcasecmp(str, "weight") == 0)
	return field_weight;
      break;
    }

  return field_custom;
}

const char *
activity::lookup_field_name(field_id id)
{
  switch (id)
    {
    case field_activity:
      return "Activity";
    case field_average_hr:
      return "Average-HR";
    case field_calories:
      return "Calories";
    case field_course:
      return "Course";
    case field_custom:
      return 0;
    case field_date:
      return "Date";
    case field_distance:
      return "Distance";
    case field_duration:
      return "Duration";
    case field_effort:
      return "Effort";
    case field_equipment:
      return "Equipment";
    case field_gps_file:
      return "GPS-File";
    case field_keywords:
      return "Keywords";
    case field_max_hr:
      return "Max-HR";
    case field_max_pace:
      return "Max-Pace";
    case field_max_speed:
      return "Max-Speed";
    case field_pace:
      return "Pace";
    case field_quality:
      return "Quality";
    case field_resting_hr:
      return "Resting-HR";
    case field_speed:
      return "Speed";
    case field_temperature:
      return "Temperature";
    case field_type:
      return "Type";
    case field_weather:
      return "Weather";
    case field_weight:
      return "Weight";
    }
}

activity::field_data_type
activity::lookup_field_data_type(field_id id)
{
  switch (id)
    {
    case field_activity:
    case field_course:
    case field_gps_file:
    case field_type:
    case field_custom:
      return type_string;
    case field_average_hr:
    case field_calories:
    case field_max_hr:
    case field_resting_hr:
    case field_weight:
      return type_number;
    case field_date:
      return type_date;
    case field_distance:
      return type_distance;
    case field_duration:
      return type_duration;
    case field_effort:
    case field_quality:
      return type_fraction;
    case field_equipment:
    case field_keywords:
    case field_weather:
      return type_keywords;
    case field_max_pace:
    case field_pace:
      return type_pace;
    case field_max_speed:
    case field_speed:
      return type_speed;
    case field_temperature:
      return type_temperature;
    }
}

bool
activity::field::operator==(const field_name &name) const
{
  if (id == name.id && id != field_custom)
    return true;

  const char *str1;
  if (id != field_custom)
    str1 = lookup_field_name(id);
  else
    str1 = custom.c_str();

  const char *str2;
  if (name.id != field_custom)
    str2 = lookup_field_name(name.id);
  else if (name.ptr)
    str2 = name.ptr;
  else
    str2 = name.str->c_str();

  return strcasecmp_l(str1, str2, nullptr) == 0;
}

activity::activity()
: _date(0)
{
}

activity::~activity()
{
}

bool
activity::read_file(const char *path)
{
  FILE *fh = fopen(path, "r");
  if (!fh)
    return false;

  _date = 0;
  _header.clear();
  _body.clear();

  field_id last_field = activity::field_custom;

  /* Using normal email-header rules: first empty line completes header
     section, and leading whitespace can be used to append a line onto
     the previous header. */

  char buf[4096];
  while (fgets(buf, sizeof(buf), fh))
    {
      if (buf[0] == '\n')
	break;

      if (_header.size() == 0 || !isspace_l(buf[0], nullptr))
	{
	  char *ptr = strchr(buf, ':');
	  if (!ptr)
	    continue;

	  *ptr++ = 0;

	  last_field = lookup_field_id(buf);

	  if (last_field != field_custom)
	    _header.push_back(field(field_name(last_field)));
	  else
	    _header.push_back(field(field_name(buf)));

	  while (*ptr && isspace_l(*ptr, nullptr))
	    ptr++;

	  trim_newline_characters(ptr);
	  _header.back().value = ptr;
	}
      else
	{
	  trim_newline_characters(buf);
	  _header.back().value.append(buf);
	}

      if (last_field == field_date)
	parse_date_time(_header.back().value, &_date, nullptr);
    }

  while (fgets(buf, sizeof(buf), fh))
    _body.append(buf);

  fclose(fh);
  return true;
}

bool
activity::write_file(const char *path) const
{
  FILE *fh = fopen(path, "w");
  if (!fh)
    return false;

  for (const auto &field : _header)
    {
      const char *field_name = lookup_field_name(field.id);
      if (!field_name)
	field_name = field.custom.c_str();

      fprintf(fh, "%s: %s\n", field_name, field.value.c_str());
    }

  fputs("\n", fh);

  fputs(_body.c_str(), fh);

  fclose(fh);
  return true;
}

bool
activity::make_filename(std::string &filename) const
{
  if (_date == 0)
    return false;

  struct tm tm = {0};
  localtime_r(&_date, &tm);

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

		  activity::field_name name(token);
		  const std::string *str;
		  if (get_string_field(name, &str))
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
      for (const auto &field : _header)
	{
	  const char *field_name = lookup_field_name(field.id);
	  if (!field_name)
	    field_name = field.custom.c_str();

	  fprintf(fh, "%s: %s\n", field_name, field.value.c_str());
	}
    }
  else if (strcasecmp(name, "body") == 0)
    {
      const char *body = _body.c_str();

      if (!arg || strcasecmp(arg, "all") == 0)
	{
	  print_indented_string(body, _body.size(), fh);
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

      struct tm tm = {0};
      localtime_r(&_date, &tm);

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
      /* FIXME: add a better way to access generic fields, with unit
	 conversions, etc. */

      activity::field_name field(name);
      const std::string *str;
      if (get_string_field(field, &str))
	fwrite(str->c_str(), 1, str->size(), fh);
    }
}

void
activity::set_date(time_t x)
{
  if (_date != x)
    {
      _date = x;

      std::string &value = field_value(field_name(field_date));

      value.clear();
      format_date_time(value, _date);
    }
}

void
activity::set_body(const std::string &x)
{
  _body = x;
}

int
activity::field_index(const field_name &name) const
{
  for (const auto &it : _header)
    {
      if (it == name)
	return &it - &_header[0];
    }

  return -1;
}

bool
activity::has_field(const field_name &name) const
{
  return field_index(name) >= 0;
}

bool
activity::get_string_field(const field_name &name,
			   const std::string **ptr) const
{
  int i = field_index(name);

  if (i >= 0)
    {
      *ptr = &_header[i].value;
      return true;
    }
  else
    return false;
}

std::string &
activity::field_value(const field_name &name)
{
  int i = field_index(name);

  if (i < 0)
    {
      _header.push_back(field(name));
      i = _header.size() - 1;
    }

  return _header[i].value;
}

void
activity::set_string_field(const field_name &name, const std::string &x)
{
  field_value(name) = x;
}

// FIXME: feels like the code below should use templates?

bool
activity::get_numeric_field(field_id id, double *ptr) const
{
  const std::string *s;
  return get_string_field(id, &s) && parse_number(*s, ptr);
}

void
activity::set_numeric_field(field_id id, double x)
{
  format_number(field_value(id), x);
}

bool
activity::get_distance_field(field_id id, double *ptr,
			     distance_unit *unit_ptr) const
{
  const std::string *s;
  return get_string_field(id, &s) && parse_distance(*s, ptr, unit_ptr);
}

void
activity::set_distance_field(field_id id, double x, distance_unit unit)
{
  format_distance(field_value(id), x, unit);
}

void
activity::set_distance_field(field_id id, const std::string &str)
{
  double dist;
  distance_unit unit;
  if (parse_distance(str, &dist, &unit))
    set_distance_field(id, dist, unit);
}

bool
activity::get_duration_field(field_id id, double *ptr) const
{
  const std::string *s;
  return get_string_field(id, &s) && parse_duration(*s, ptr);
}

void
activity::set_duration_field(field_id id, double x)
{
  format_duration(field_value(id), x);
}

void
activity::set_duration_field(field_id id, const std::string &str)
{
  double dur;
  if (parse_duration(str, &dur))
    set_duration_field(id, dur);
}

bool
activity::get_pace_field(field_id id, double *ptr, pace_unit *unit_ptr) const
{
  const std::string *s;
  return get_string_field(id, &s) && parse_pace(*s, ptr, unit_ptr);
}

void
activity::set_pace_field(field_id id, double x, pace_unit unit)
{
  format_pace(field_value(id), x, unit);
}

void
activity::set_pace_field(field_id id, const std::string &str)
{
  double pace;
  pace_unit unit;
  if (parse_pace(str, &pace, &unit))
    set_pace_field(id, pace, unit);
}

bool
activity::get_speed_field(field_id id, double *ptr, speed_unit *unit_ptr) const
{
  const std::string *s;
  return get_string_field(id, &s) && parse_speed(*s, ptr, unit_ptr);
}

void
activity::set_speed_field(field_id id, double x, speed_unit unit)
{
  format_speed(field_value(id), x, unit);
}

void
activity::set_speed_field(field_id id, const std::string &str)
{
  double speed;
  speed_unit unit;
  if (parse_speed(str, &speed, &unit))
    set_speed_field(id, speed, unit);
}

bool
activity::get_temperature_field(field_id id, double *ptr,
				temperature_unit *unit_ptr) const
{
  const std::string *s;
  return get_string_field(id, &s) && parse_temperature(*s, ptr, unit_ptr);
}

void
activity::set_temperature_field(field_id id, double x, temperature_unit unit)
{
  format_temperature(field_value(id), x, unit);
}

void
activity::set_temperature_field(field_id id, const std::string &str)
{
  double temp;
  temperature_unit unit;
  if (parse_temperature(str, &temp, &unit))
    set_temperature_field(id, temp, unit);
}

bool
activity::get_keywords_field(field_id id, std::vector<std::string> *ptr) const
{
  const std::string *s;
  return get_string_field(id, &s) && parse_keywords(*s, ptr);
}

void
activity::set_keywords_field(field_id id, const std::vector<std::string> &x)
{
  format_keywords(field_value(id), x);
}

void
activity::set_keywords_field(field_id id, const std::string &str)
{
  std::vector<std::string> keys;
  if (parse_keywords(str, &keys))
    set_keywords_field(id, keys);
}

bool
activity::get_fraction_field(field_id id, double *ptr) const
{
  const std::string *s;
  return get_string_field(id, &s) && parse_fraction(*s, ptr);
}

void
activity::set_fraction_field(field_id id, double x)
{
  format_fraction(field_value(id), x);
}

void
activity::set_fraction_field(field_id id, const std::string &str)
{
  double frac;
  if (parse_fraction(str, &frac))
    set_fraction_field(id, frac);
}

void
activity::canonicalize_field_order()
{
  std::sort(_header.begin(), _header.end(),
	    [] (const field &a, const field &b) {
	      return a.id < b.id;
	    });
}

bool
activity::canonicalize_field_string(field_id id, std::string &str)
{
  switch (lookup_field_data_type(id))
    {
    case type_string:
      return true;

    case type_number: {
      double value;
      if (parse_number(str, &value))
	{
	  str.clear();
	  format_number(str, value);
	  return true;
	}
      break; }

    case type_date: {
      time_t date;
      if (parse_date_time(str, &date, nullptr))
	{
	  str.clear();
	  format_date_time(str, date);
	  return true;
	}
      break; }

    case type_duration: {
      double dur;
      if (parse_duration(str, &dur))
	{
	  str.clear();
	  format_duration(str, dur);
	  return true;
	}
      break; }

    case type_distance: {
      double dist;
      distance_unit unit;
      if (parse_distance(str, &dist, &unit))
	{
	  str.clear();
	  format_distance(str, dist, unit);
	  return true;
	}
      break; }

    case type_pace: {
      double pace;
      pace_unit unit;
      if (parse_pace(str, &pace, &unit))
	{
	  str.clear();
	  format_pace(str, pace, unit);
	  return true;
	}
      break; }

    case type_speed: {
      double speed;
      speed_unit unit;
      if (parse_speed(str, &speed, &unit))
	{
	  str.clear();
	  format_speed(str, speed, unit);
	  return true;
	}
      break; }

    case type_temperature: {
      double temp;
      temperature_unit unit;
      if (parse_temperature(str, &temp, &unit))
	{
	  str.clear();
	  format_temperature(str, temp, unit);
	  return true;
	}
      break; }

    case type_fraction: {
      double value;
      if (parse_fraction(str, &value))
	{
	  str.clear();
	  format_fraction(str, value);
	  return true;
	}
      break; }

    case type_keywords: {
      std::vector<std::string> keys;
      if (parse_keywords(str, &keys))
	{
	  str.clear();
	  format_keywords(str, keys);
	  return true;
	}
      break; }
    }

  return false;
}

} // namespace act
