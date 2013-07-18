// -*- c-style: gnu -*-

#include "act-arguments.h"

namespace act {

arguments::arguments(int argc, const char **argv)
: _program_name(argc > 0 ? argv[0] : 0),
  _getopt_finished(false)
{
  for (int i = 1; i < argc; i++)
    _args.push_back(argv[i]);
}

arguments::arguments(const arguments &rhs)
: _program_name(rhs._program_name),
  _args(rhs._args),
  _getopt_finished(rhs._getopt_finished)
{
}

arguments::~arguments()
{
  for (char *str : _allocations)
    delete str;
}

bool
arguments::program_name_p(const char *name) const
{
  if (!_program_name)
    return false;

  const char *arg0 = _program_name;
  if (const char *start = strrchr(arg0, '/'))
    arg0 = start + 1;

  return strcmp(arg0, name) == 0;
}

void
arguments::push_back(const char *arg)
{
  char *copy = strdup(arg);
  _allocations.push_back(copy);
  _args.push_back(copy);
}

int
arguments::getopt(const struct option *opts,
		  const char **arg_ptr, uint32_t flags)
{
  if (_getopt_finished || _args.size() < 1)
    return opt_eof;

  const char *arg = _args[0];

  if (arg[0] == '-' && arg[1] == '-')
    {
      _args.erase(_args.begin());

      if (arg[2] == 0)
	{
	  _getopt_finished = true;
	  return opt_eof;
	}

      /* long option. */

      const char *start = arg + 2;

      if (const char *end = strchr(start, '='))
	{
	  /* --opt=value */

	  for (size_t i = 0; opts[i].option_id >= 0; i++)
	    {
	      if (strncasecmp(start, opts[i].long_option, end - start) != 0
		  || opts[i].long_option[end - start] != 0)
		continue;

	      if (!opts[i].arg_name)
		{
		  if (flags & opt_partial)
		    return opt_eof;

		  *arg_ptr = arg;
		  return opt_error;
		}

	      *arg_ptr = end + 1;
	      return opts[i].option_id;
	    }

          *arg_ptr = arg;
	  return opt_error;
	}
      else
	{
	  /* --opt [VALUE] */

	  for (size_t i = 0; opts[i].option_id >= 0; i++)
	    {
	      if (strcasecmp(start, opts[i].long_option) != 0)
		continue;

	      if (opts[i].arg_name)
		{
		  if (_args.size() < 1)
		    {
		      *arg_ptr = arg;
		      return opt_error;
		    }

		  *arg_ptr = _args[0];
		  _args.erase(_args.begin());
		}
	      else
		*arg_ptr = 0;

	      return opts[i].option_id;
	    }

	  if (flags & opt_partial)
	    return opt_eof;

          *arg_ptr = arg;
	  return opt_error;
	}
    }
  else if (arg[0] == '-')
    {
      // FIXME: single character options are not currently supported.
      *arg_ptr = arg;
      return opt_error;
    }

  return opt_eof;
}

void
arguments::print_options(const struct option *opts, FILE *fh)
{
  for (size_t i = 0; opts[i].option_id >= 0; i++)
    {
      char buf[256];

      if (opts[i].long_option)
	{
	  if (opts[i].arg_name)
	    snprintf(buf, sizeof(buf), "--%s=%s", opts[i].long_option, opts[i].arg_name);
	  else
	    snprintf(buf, sizeof(buf), "--%s", opts[i].long_option);
	}
      else if (opts[i].short_option)
	{
	  if (opts[i].arg_name)
	    snprintf(buf, sizeof(buf), "-%c %s", opts[i].short_option, opts[i].arg_name);
	  else
	    snprintf(buf, sizeof(buf), "-%c", opts[i].short_option);
	}
      else
	continue;

      if (!opts[i].desc)
	fprintf(fh, "    %s\n", buf);
      else
	fprintf(fh, "    %-32s %s\n", buf, opts[i].desc);
    }
}


} // namespace act
