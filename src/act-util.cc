// -*- c-style: gnu -*-

#include "act-util.h"

#include <dirent.h>
#include <errno.h>
#include <sys/stat.h>
#include <string.h>
#include <unistd.h>

namespace act {

bool
string_has_suffix(const std::string &str, const char *suffix)
{
  size_t len = strlen(suffix);
  if (str.size() < len)
    return false;

  return str.compare(str.size() - len, std::string::npos, suffix) == 0;
}

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

bool
make_path(const char *path)
{
  if (path[0] != '/')
    return false;

  malloc_ptr<char> buf (strlen(path) + 1);
  if (!buf)
    return false;

  for (const char *ptr = strchr (path + 1, '/');
       ptr; ptr = strchr(ptr + 1, '/'))
    {
      memcpy(&buf[0], path, ptr - path);
      buf[ptr - path] = 0;

      if (mkdir(&buf[0], 0777) != 0 && errno != EEXIST)
	return false;
    }

  return true;
}

} // namespace act
