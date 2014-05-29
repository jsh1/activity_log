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

#include "act-config.h"

#include "act-format.h"
#include "act-util.h"

#include <xlocale.h>

namespace act {

const char *(*config::_getenv)(const char *key);

const char *
config::getenv(const char *key)
{
  if (_getenv != nullptr)
    return _getenv(key);
  else
    return ::getenv(key);
}

config::config()
: _default_distance_unit(unit_type::miles),
  _default_height_unit(unit_type::metres),
  _default_pace_unit(unit_type::seconds_per_mile),
  _default_speed_unit(unit_type::miles_per_hour),
  _default_temperature_unit(unit_type::celsius),
  _default_weight_unit(unit_type::kilogrammes),
  _default_efficiency_unit(unit_type::beats_per_mile),
  _start_of_week(0),
  _resting_hr(0),
  _max_hr(0),
  _vdot(0),
  _silent(false),
  _verbose(false)
{
  if (const char *home = ::getenv("HOME"))
    {
      _activity_dir = home;
      _gps_file_dir = home;
#if defined(__APPLE__) && __APPLE__
      _activity_dir.append("/Documents/Activities");
      _gps_file_dir.append("/Documents/Garmin");
#else
      _activity_dir.append("/.activities");
      _gps_file_dir.append("/.garmin");
#endif
    }

  if (const char *file = getenv("ACT_CONFIG"))
    read_config_file(file);
  else if (const char *home = ::getenv("HOME"))
    {
      std::string file(home);
      file.append("/.actconfig");
      read_config_file(file.c_str());
    }

  if (const char *dir = getenv("ACT_DIR"))
    _activity_dir = dir;

  if (_activity_dir.size() == 0)
    {
      fprintf(stderr, "Error: you need to set $ACT_DIR or $HOME.\n");
      exit(1);
    }

  if (const char *dir = getenv("ACT_GPS_DIR"))
    _gps_file_dir = dir;

  if (const char *path = getenv("ACT_GPS_PATH"))
    append_gps_file_path(path, false);
  else
    _gps_file_path.push_back(_gps_file_dir);

  if (const char *opt = getenv("ACT_START_OF_WEEK"))
    set_start_of_week(opt);

  if (const char *opt = getenv("ACT_RESTING_HR"))
    _resting_hr = atoi(opt);

  if (const char *opt = getenv("ACT_MAX_HR"))
    _max_hr = atoi(opt);

  if (const char *opt = getenv("ACT_VDOT"))
    _vdot = atof(opt);

  if (const char *opt = getenv("ACT_SILENT"))
    _silent = atoi(opt) != 0;

  if (const char *opt = getenv("ACT_VERBOSE"))
    _verbose = atoi(opt) != 0;
}

config::~config()
{
}

const config &
shared_config()
{
  static const config *cfg = new config();
  return *cfg;
}

void
config::read_config_file(const char *path)
{
  FILE_ptr fh(fopen(path, "r"));
  if (!fh)
    return;

  std::string section;

  char buf[4096];
  while (fgets(buf, sizeof(buf), fh.get()))
    {
      if (buf[0] == '[')
	{
	  if (char *end = strchr(buf, ']'))
	    {
	      *end = 0;
	      section = buf + 1;
	    }
	  continue;
	}

      if (section.size() == 0)
	continue;

      char *ptr = buf;
      while (*ptr && isspace_l(*ptr, nullptr))
	ptr++;
      if (*ptr == 0)
	continue;

      char *eol;
      if ((eol = strchr(ptr, '#')) || (eol = strchr(ptr, ';')))
	*eol = 0;
      else
	eol = ptr + strlen(ptr);

      while (eol > ptr && isspace_l(eol[-1], nullptr))
	eol--, *eol = 0;
      if (ptr == eol)
	continue;

      const char *name = nullptr;
      const char *value = nullptr;

      if (char *eql = strchr(ptr, '='))
	{
	  char *end = eql;
	  while (end > ptr && isspace_l(end[-1], nullptr))
	    end--;
	  name = ptr;
	  *end = 0;

	  eql++;
	  while (*eql != 0 && isspace_l(*eql, nullptr))
	    eql++;
	  value = eql;
	}
      else
	{
	  name = ptr;
	  value = "true";
	}

      // apply section.name = value

      if (strcmp(section.c_str(), "user") == 0)
	{
	  if (strcmp(name, "resting-heart-rate") == 0)
	    _resting_hr = atoi(value);
	  else if (strcmp(name, "max-heart-rate") == 0)
	    _max_hr = atoi(value);
	  else if (strcmp(name, "vdot") == 0)
	    _vdot = strtod(value, nullptr);
	}
      else if (strcmp(section.c_str(), "files") == 0)
	{
	  if (strcmp(name, "activity-directory") == 0)
	    tilde_expand_file_name(_activity_dir, value);
	  else if (strcmp(name, "gps-file-directory") == 0)
	    tilde_expand_file_name(_gps_file_dir, value);
	  else if (strcmp(name, "gps-file-path") == 0)
	    append_gps_file_path(value, true);
	}
      else if (strcmp(section.c_str(), "units") == 0)
	{
	  if (strcmp(name, "default-distance-unit") == 0)
	    {
	      parse_unit(std::string(value), field_data_type::distance,
			 _default_distance_unit);
	    }
	  if (strcmp(name, "default-height-unit") == 0)
	    {
	      parse_unit(std::string(value), field_data_type::distance,
			 _default_height_unit);
	    }
	  else if (strcmp(name, "default-pace-unit") == 0)
	    {
	      parse_unit(std::string(value), field_data_type::pace,
			 _default_pace_unit);
	    }
	  else if (strcmp(name, "default-speed-unit") == 0)
	    {
	      parse_unit(std::string(value), field_data_type::speed,
			 _default_speed_unit);
	    }
	  else if (strcmp(name, "default-temperature-unit") == 0)
	    {
	      parse_unit(std::string(value), field_data_type::temperature,
			 _default_temperature_unit);
	    }
	  else if (strcmp(name, "default-weight-unit") == 0)
	    {
	      parse_unit(std::string(value), field_data_type::weight,
			 _default_weight_unit);
	    }
	  else if (strcmp(name, "default-efficiency-unit") == 0)
	    {
	      parse_unit(std::string(value), field_data_type::efficiency,
			 _default_efficiency_unit);
	    }
	}
      else if (strcmp(section.c_str(), "calendar") == 0)
	{
	  if (strcmp(name, "start-of-week") == 0)
	    {
	      set_start_of_week(value);
	    }
	}
    }
}

void
config::set_start_of_week(const char *value)
{
  if (isdigit_l(value[0], nullptr))
    {
      _start_of_week = atoi(value);
    }
  else
    {
      if (strcmp(value, "sunday") == 0)
	_start_of_week = 0;
      else if (strcmp(value, "monday") == 0)
	_start_of_week = 1;
      else if (strcmp(value, "tuesday") == 0)
	_start_of_week = 2;
      else if (strcmp(value, "wednesday") == 0)
	_start_of_week = 3;
      else if (strcmp(value, "thursday") == 0)
	_start_of_week = 4;
      else if (strcmp(value, "friday") == 0)
	_start_of_week = 5;
      else if (strcmp(value, "saturday") == 0)
	_start_of_week = 6;
      else
	printf("warning: unknown start-of-week: %s\n", value);
    }
}

void
config::append_gps_file_path(const char *path_str, bool tilde_expand)
{
  while (const char *ptr = strchr(path_str, ':'))
    {
      std::string str(path_str, ptr - path_str);
      if (tilde_expand)
	tilde_expand_file_name(str);
      _gps_file_path.push_back(str);
      path_str = ptr + 1;
    }

  if (*path_str != 0)
    {
      std::string str(path_str);
      if (tilde_expand)
	tilde_expand_file_name(str);
      _gps_file_path.push_back(str);
    }
}

void
config::find_new_gps_files(std::vector<std::string> &files) const
{
}

/* Modifies 'str' to be absolute if the named file is found. */

bool
config::find_gps_file(std::string &str) const
{
  if (_gps_file_dir.size() > 0)
    return find_file_under_directory(str, _gps_file_dir.c_str());
  else
    return false;
}

void
config::edit_file(const char *filename) const
{
  const char *editor = getenv("ACT_EDITOR");
  if (!editor)
    editor = ::getenv("VISUAL");
  if (!editor)
    editor = ::getenv("EDITOR");

  char *command = nullptr;
  asprintf(&command, "\'%s\' '%s'", editor, filename);

  if (command)
    {
      system(command);
      free(command);
    }
}

} // namespace act
