// -*- c-style: gnu -*-

#include "act-activity.h"

namespace activity_log {

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
}

bool
activity::write_file(const char *path)
{
}

void
activity::set_date(time_t x)
{
  if (_date == x)
    return;

  _date = x;
  format_date(field_value(field_name(field_date)), x);
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
activity::contains_field(const field_name &name) const
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
