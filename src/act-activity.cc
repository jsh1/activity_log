// -*- c-style: gnu -*-

#include "act-activity.h"

namespace activity_log {

field_id
activity::lookup_field_id(const char *str)
{
  switch (tolower_l(str[0], 0))
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

    case 'f':
      if (strcasecmp(str, "fit-file") == 0)
	return field_fit_file;
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
      if (strcasecmp(str, "tcx-file") == 0)
	return field_tcx_file;
      else if (strcasecmp(str, "temperature") == 0)
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
    case field_fit_file:
      return "FIT-File";
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
    case field_tcx_file:
      return "TCX-File";
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
  _body = "";

  char buf[4096];

  while (fgets(buf, sizeof(buf), fh))
    {
      if (buf[0] == '\n')
	break;

      const char *ptr = strchr(buf, ':');
      if (!ptr)
	continue;

      *ptr++ = 0;

      field_id id = lookup_field_id(buf);
      if (id != field_custom)
	_header.push_back(field(field_name(id)));
      else
	_header.push_back(field(field_name(buf)));

      while (*ptr && isspace_l(*ptr))
	ptr++;

      const char *end = ptr + strlen(ptr);
      while (end > ptr + 1 && isspace_l(end[-1]))
	*end-- = 0;

      _header.back()->value = ptr;

      if (id == field_date)
	parse_date(_header.back()->value, &_date, 0);
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
      const char *field = lookup_field_name(field.id);
      if (!field)
	field = field.custom.c_str();

      fprintf(fh, "%s: %s\n", field, field.value.c_str());
    }

  fputs("\n", fh);

  fputs(_body.c_str());

  fclose(fh);
  return true;
}

namespace {

bool
ensure_path(const char *path)
{
  if (path[0] != '/')
    return false;

  char *buf = malloc(strlen(path) + 1);

  for (const char *ptr = strchr (path + 1, '/');
       ptr; ptr = strchr(ptr + 1, '/'))
    {
      memcpy(buf, path, ptr - path - 1);
      buf[ptr - path] = 0;

      if (mkdir(buf, 0777) != 0 && errno != EEXIST)
	{
	  free(buf);
	  return false;
	}
    }

  free(buf);
  return true;
}

} // anonymous namespace

bool
activity::make_filename(std::string &filename) const
{
  if (_date == 0)
    return false;

  struct tm tm = {0};
  gmtime_r(&_date, &tm);

  filename = shared_config().activity_file_dir();
  if (filename.size() > 1 && filename[filename.size() - 1] != '/')
    filename.append('/');

  char buf[256];
  strftime(buf, sizeof(buf), "%Y/%m/%Y-%m-%d-%H-%M-%S.txt", &tm);
  filename.append(buf);

  return ensure_path(filename.c_str());
}

void
activity::set_date(time_t x)
{
  if (_date != x)
    {
      _date = x;

      std::string &value = field_value(field_name(field_date));

      value = "";
      format_date(value, _date);
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
  for (int i = 0; i < _header.size(); i++)
    {
      if (_header[i] == name)
	return i;
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
			   const std::string &*ptr) const
{
  int i = field_index(name);

  if (i >= 0)
    {
      *ptr = _header[i].str;
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

  return _header[i].str;
}

void
activity::set_string_field(const field_name &name, const std::string &x)
{
  string_field(name) = x;
}

// FIXME: feels like the code below should use templates?

bool
activity::get_distance_field(const field_name &name, double *ptr) const
{
  const std::string &s;
  return get_string_field(name, &s) && parse_distance(s, ptr);
}

void
activity::set_distance_field(const field_name &name, double x)
{
  format_distance(field_value(name), x);
}

bool
activity::get_duration_field(const field_name &name, double *ptr) const
{
  const std::string &s;
  return get_string_field(name, &s) && parse_duration(s, ptr);
}

void
activity::set_duration_field(const field_name &name, double x)
{
  format_duration(field_value(name), x);
}

bool
activity::get_pace_field(const field_name &name, double *ptr) const
{
  const std::string &s;
  return get_string_field(name, &s) && parse_pace(s, ptr);
}

void
activity::set_pace_field(const field_name &name, double x)
{
  format_pace(field_value(name), x);
}

bool
activity::get_speed_field(const field_name &name, double *ptr) const
{
  const std::string &s;
  return get_string_field(name, &s) && parse_speed(s, ptr);
}

void
activity::set_speed_field(const field_name &name, double x)
{
  format_speed(field_value(name), x);
}

bool
activity::get_temperature_field(const field_name &name, double *ptr) const
{
  const std::string &s;
  return get_string_field(name, &s) && parse_temperature(s, ptr);
}

void
activity::set_temperature_field(const field_name &name, double x)
{
  format_temperature(field_value(name), x);
}

bool
activity::get_keywords_field(const field_name &name,
			     std::vector<std::string> *ptr) const
{
  const std::string &s;
  return get_string_field(name, &s) && parse_keywords(s, ptr);
}

void
activity::set_keywords_field(const field_name &name,
			     const std::vector<std::string> &x)
{
  format_keywords(field_value(name), x);
}

bool
activity::get_fraction_field(const field_name &name, double &ptr) const
{
  const std::string &s;
  return get_string_field(name, &s) && parse_fraction(s, ptr);
}

void
activity::set_fraction_field(const field_name &name, double x)
{
  format_fraction(field_value(name), x);
}

} // namespace activity_log
