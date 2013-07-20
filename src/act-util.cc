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

void
trim_newline_characters(char *ptr)
{
  char *end = ptr + strlen(ptr);
  while (end > ptr + 1)
    {
      switch (end[-1])
	{
	case '\n':
	case '\r':
	  end[-1] = 0;
	  end--;
	  break;
	default:
	  return;
	}
    }
}	 

namespace {

struct DIR_wrapper
{
  DIR *dir;

  explicit DIR_wrapper(DIR *d) : dir(d) {}
  ~DIR_wrapper() {closedir(dir);}
};

} // anonymous namespace

bool
find_file_under_directory(std::string &file, const char *dir)
{
  DIR_wrapper d(opendir(dir));

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

	      if (find_file_under_directory(file, subdir.c_str()))
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

void
map_directory_files(const char *dir,
		    void (*fun) (const char *path, void *ctx), void *ctx)
{
  DIR_wrapper d(opendir(dir));

  if (d.dir)
    {
      while (struct dirent *de = readdir(d.dir))
	{
	  if (de->d_name[0] == '.'
	      || de->d_name[de->d_namlen-1] == '~')
	    {
	      continue;
	    }

	  std::string file(dir);
	  file.push_back('/');
	  file.append(de->d_name);

	  if (de->d_type == DT_DIR)
	    map_directory_files(file.c_str(), fun, ctx);
	  else
	    fun(file.c_str(), ctx);
	}
    }      
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

bool
path_has_extension(const char *path, const char *ext)
{
  path = strrchr(path, '.');
  if (!path)
    return false;

  return strcasecmp(path + 1, ext) == 0;
}

} // namespace act
