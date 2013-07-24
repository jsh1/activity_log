// -*- c-style: gnu -*-

#include "act-gps-activity.h"
#include "act-gps-parser.h"
#include "act-gps-fit-parser.h"
#include "act-gps-tcx-parser.h"

#include <getopt.h>
#include <math.h>

using namespace act;

static const struct option long_options[] =
{
  {"fit", no_argument, 0, 'f'},
  {"tcx", no_argument, 0, 't'},
  {"print-summary", no_argument, 0, 's'},
  {"print-laps", no_argument, 0, 'l'},
};

static const char short_options[] = "ftsl";

static void
usage_and_exit(int ret)
{
  fprintf(stderr, "usage: gps-test [OPTIONS] FILES...\n");
  exit(ret);
}

int
main(int argc, char **argv)
{
  bool opt_fit = false;
  bool opt_tcx = false;
  bool opt_print_summary = false;
  bool opt_print_laps = false;

  while (1)
    {
      int opt = getopt_long(argc, argv, short_options, long_options, 0);
      if (opt == -1)
	break;

      switch (opt)
	{
	case 'f':
	  opt_fit = true;
	  break;

	case 't':
	  opt_tcx = true;
	  break;

	case 's':
	  opt_print_summary = true;
	  break;

	case 'l':
	  opt_print_laps = true;
	  break;

	default:
	  usage_and_exit(1);
	}
    }

  for (int i = optind; i < argc; i++)
    {
      gps::activity test_activity;

      if (opt_fit)
	test_activity.read_fit_file(argv[i]);
      else if (opt_tcx)
	test_activity.read_tcx_file(argv[i]);
      else
	test_activity.read_file(argv[i]);

      if (opt_print_summary)
	test_activity.print_summary(stdout);

      if (opt_print_laps)
	{
	  fputc('\n', stdout);
	  test_activity.print_laps(stdout);
	}
    }

  return 0;
}
