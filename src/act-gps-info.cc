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
  {"print-date", required_argument, 0, 'd'},
};

static const char short_options[] = "ftsld:";

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
  const char *opt_print_date = nullptr;

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

	case 'd':
	  opt_print_date = optarg;
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

      if (opt_print_date)
	{
	  time_t d = (time_t) test_activity.start_time();
	  if (d == 0)
	    continue;

	  struct tm tm = {0};
	  localtime_r(&d, &tm);

	  char buf[1024];
	  strftime(buf, sizeof(buf), opt_print_date, &tm);

	  printf("%s\n", buf);
	}

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
