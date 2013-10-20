// -*- c-style: gnu -*-

#include "act-util.h"

#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>
#include <xlocale.h>

namespace act {

size_t
case_insensitive_string_hash::operator() (const char *ptr) const
{
  size_t h = 0;
  while (int c = *ptr++)
    h = h * 33 + tolower_l(c, nullptr);
  return h;
}

bool
case_insensitive_string_pred::operator() (const char *a, const char *b) const
{
  return strcasecmp_l(a, b, nullptr) == 0;
}

bool
case_insensitive_string_compare::operator() (const char *a,
					     const char *b) const
{
  return strcasecmp_l(a, b, nullptr) < 0;
}

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

bool
matches_word_list(const char *str, const char *lst)
{
  for (const char *wptr = lst; *wptr; wptr += strlen(wptr) + 1)
    {
      if (strcasecmp_l(str, wptr, nullptr) == 0)
	return true;
    }

  return false;
}

bool
find_file_under_directory(std::string &file, const char *dir)
{
  DIR_ptr d(opendir(dir));

  if (d.get())
    {
      while (struct dirent *de = readdir(d.get()))
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
  DIR_ptr d(opendir(dir));

  if (d)
    {
      while (struct dirent *de = readdir(d.get()))
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

void
cat_file(const char *src)
{
  FILE_ptr f(fopen(src, "r"));

  if (f)
    {
      char buf[4096];
      while (size_t n = fread(buf, 1, sizeof(buf), f.get()))
	fwrite(buf, 1, n, stdout);
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
  if (const char *ptr = strcasestr(path, ext))
    return strlen(ptr) == strlen(ext);
  else
    return false;
}

void
tilde_expand_file_name(std::string &dest, const char *src)
{
  dest.clear();

  if (src[0] == '~' && src[1] == '/')
    {
      if (const char *home_dir = getenv("HOME"))
	{
	  dest.append(home_dir);
	  src++;
	}
    }

  dest.append(src);
}

output_pipe::output_pipe(const char *program_path,
			 const char *const program_argv[])
: _program_path(program_path),
  _program_argv(program_argv),
  _child_pid(0),
  _output_fd(-1)
{
}

output_pipe::~output_pipe()
{
  // reap the zombie
  finish();

  if (_output_fd >= 0)
    close(_output_fd);
}

bool
output_pipe::start()
{
  if (_child_pid == 0)
    {
      int fds[2];

      if (pipe(fds) < 0)
	return false;

      pid_t pid = vfork();
      switch (pid)
	{
	case -1:			// error
	  close(fds[0]);
	  close(fds[1]);
	  break;

	case 0:				// child
	  if (dup2(fds[1], 1) != 1)
	    _exit(1);
	  close(fds[0]);
	  close(fds[1]);
	  execvp(_program_path, (char *const *)_program_argv);
	  _exit(1);

	default:			// parent
	  _child_pid = pid;
	  _output_fd = fds[0];
	  close(fds[1]);
	}
    }

  return _child_pid != 0;
}

bool
output_pipe::finish()
{
  if (_child_pid == 0)
    return true;

  kill(_child_pid, SIGTERM);

  int stat = 0, ret;

  while ((ret = waitpid(_child_pid, &stat, 0)) < 0 && errno == EINTR)
    {
    }

  _child_pid = 0;

  if (ret > 0)
    return WIFEXITED(stat) && WEXITSTATUS(stat) == 0;
  else
    return false;
}

FILE *
output_pipe::open_output(const char *mode)
{
  if (_output_fd >= 0)
    {
      if (FILE *fh = fdopen(_output_fd, mode))
	{
	  _output_fd = -1;
	  return fh;
	}
    }

  return nullptr;
}

} // namespace act
