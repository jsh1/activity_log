// -*- c-style: gnu -*-

#include "act-arguments.h"
#include "act-config.h"

#include <unistd.h>

using namespace act;

namespace {

enum option_id
{
  opt_dir,
  opt_gps_dir,
};

const arguments::option options[] =
{
  {opt_dir, "dir", 0, "ACTIVITY-DIR"},
  {opt_gps_dir, "gps-dir", 0, "GPS-FILE-DIR"},
  {arguments::opt_eof}
};

void
print_usage(const arguments &args)
{
  fputs("usage: act [OPTIONS...] COMMAND [ARGS...]\n", stderr);

  arguments::print_options(options, stderr);
}

} // anonymous namespace

int
main(int argc, const char **argv)
{
  arguments args(argc, argv);

  while (1)
    {
      const char *opt_arg = 0;
      int opt = args.getopt(options, &opt_arg);
      if (opt == arguments::opt_eof)
	break;

      switch (opt)
	{
	case opt_dir:
	  setenv("ACT_DIR", opt_arg, true);
	  break;

	case opt_gps_dir:
	  setenv("ACT_GPS_DIR", opt_arg, true);
	  break;

	case arguments::opt_error:
	  fprintf(stderr, "Error: invalid argument: %s\n", opt_arg);
	  print_usage(args);
	  return 1;
	}
    }

  if (argc < 1)
    {
      print_usage(args);
      return 1;
    }

  std::vector<const char *> exec_args (args.args());

  std::string program("act-");
  program.append(exec_args[0]);
  exec_args[0] = program.c_str();

  exec_args.push_back(0);

  execvp(exec_args[0], (char **) &exec_args[0]);

  fprintf(stderr, "Error: unable to exec %s.\n", exec_args[0]);
  return 1;
}
