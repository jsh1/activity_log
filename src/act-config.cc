// -*- c-style: gnu -*-

#include "act-config.h"

#include <dirent.h>
#include <unistd.h>
#include <sys/stat.h>

namespace act {

config::config()
{
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
config::find_new_gps_files(std::vector<std::string> &files) const
{
}

namespace {

/* Modifies 'file' to be absolute if the named file is found. */

bool
find_file_under_directory(std::string &file, const std::string &dir)
{
  struct DIR_wrapper
    {
      DIR *dir;

      explicit DIR_wrapper(DIR *d) : dir(d) {}
      ~DIR_wrapper() {closedir(dir);}
    };

  DIR_wrapper d(opendir(dir.c_str()));

  if (d.dir)
    {
      while (struct dirent *de = readdir(d.dir))
	{
	  if (de->d_type == DT_DIR)
	    {
	      if (de->d_name[0] == '.'
		  && (de->d_name[1] == 0
		      || (de->d_name[1] == '.' && de->d_name[2] == 0)))
		{
		  /* "." or ".." */
		  continue;
		}

	      std::string subdir(dir);
	      subdir.push_back('/');
	      subdir.append(de->d_name);

	      if (find_file_under_directory(file, subdir))
		return true;
	    }
	  else
	    {
	      if (file == de->d_name)
		{
		  file = dir;
		  file.push_back('/');
		  file.append(de->d_name);

		  return true;
		}
	    }
	}
    }

  return false;
}

} // anonymous namespace

/* Modifies 'str' to be absolute if the named file is found. */

bool
config::find_gps_file(std::string &str) const
{
  if (_gps_file_dir.size() > 0)
    return find_file_under_directory(str, _gps_file_dir);
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

  char *command = 0;
  asprintf(&command, "\'%s\' '%s'", editor, filename);

  if (command)
    {
      system(command);
      free(command);
    }
}

} // namespace act
