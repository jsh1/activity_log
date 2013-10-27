// -*- c-style: gnu -*-

#include "act-config.h"

#include "act-format.h"
#include "act-util.h"

#include <xlocale.h>

namespace act {

config::config()
: _default_distance_unit(unit_type::miles),
  _default_height_unit(unit_type::metres),
  _default_pace_unit(unit_type::seconds_per_mile),
  _default_speed_unit(unit_type::miles_per_hour),
  _default_temperature_unit(unit_type::celsius),
  _default_weight_unit(unit_type::kilogrammes),
  _start_of_week(0),
  _resting_hr(0),
  _max_hr(0),
  _vdot(0),
  _silent(false),
  _verbose(false)
{
  if (const char *file = getenv("ACT_CONFIG"))
    read_config_file(file);
  else if (const char *home = getenv("HOME"))
    {
      std::string file(home);
      file.append("/.actconfig");
      read_config_file(file.c_str());
    }

  if (const char *dir = getenv("ACT_DIR"))
    _activity_dir = dir;
  else if (const char *home = getenv("HOME"))
    {
      _activity_dir = home;
#if defined(__APPLE__) && __APPLE__
      _activity_dir.append("/Documents/Activities");
#else
      _activity_dir.append("/.activities");
#endif
    }
  else
    {
      fprintf(stderr, "Error: you need to set $ACT_DIR or $HOME.\n");
      exit(1);
    }

  if (const char *dir = getenv("ACT_GPS_DIR"))
    _gps_file_dir = dir;
#if defined(__APPLE__) && __APPLE__
  else if (const char *home = getenv("HOME"))
    {
      _gps_file_dir = home;
      _gps_file_dir.append("/Documents/Garmin");
    }
#endif

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
    editor = getenv("VISUAL");
  if (!editor)
    editor = getenv("EDITOR");

  char *command = nullptr;
  asprintf(&command, "\'%s\' '%s'", editor, filename);

  if (command)
    {
      system(command);
      free(command);
    }
}

} // namespace act
