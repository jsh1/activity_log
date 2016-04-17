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

#include "act-arguments.h"
#include "act-gps-activity.h"
#include "act-gps-parser.h"
#include "act-gps-fit-parser.h"
#include "act-gps-tcx-parser.h"

#include <getopt.h>

using namespace act;

enum option_id
{
  opt_fit,
  opt_tcx,
  opt_print_summary,
  opt_print_laps,
  opt_print_points,
  opt_print_smoothed,
  opt_print_date,
  opt_global_time,
};

static const arguments::option options[] =
{
  {opt_fit, "fit", 'f', nullptr, "Treat as FIT data."},
  {opt_tcx, "tcx", 't', nullptr, "Treat as XML TCX data." },
  {opt_print_summary, "print-summary", 's', nullptr,
   "Print activity summary."},
  {opt_print_laps, "print-laps", 'l', nullptr, "Print lap summaries."},
  {opt_print_points, "print-points", 'p', nullptr, "Print raw GPS track."},
  {opt_print_smoothed, "print-smoothed", 'S', "SECONDS",
   "Print smoothed GPS track."},
  {opt_print_date, "print-date", 'd', "DATE-FORMAT", "Print activity date."},
  {opt_global_time, "global-time", 'g', nullptr, "Print date as UTC."},
  {arguments::opt_eof},
};

static void
print_usage(const arguments &args)
{
  fprintf(stderr, "usage: %s [OPTION...] FILE...\n\n", args.program_name());
  fputs("where OPTION is any of:\n\n", stderr);

  arguments::print_options(options, stderr);

  fputs("\n", stderr);
}

int
main(int argc, const char **argv)
{
  arguments args(argc, argv);

  bool fit_data = false;
  bool tcx_data = false;
  bool print_summary = false;
  bool print_laps = false;
  bool print_points = false;
  int print_smoothed = 0;
  const char *print_date = nullptr;
  bool global_time = false;

  while (1)
    {
      const char *opt_arg = nullptr;

      int opt = args.getopt(options, &opt_arg);
      if (opt == arguments::opt_eof)
	break;

      switch (opt)
	{
	case opt_fit:
	  fit_data = true;
	  break;

	case opt_tcx:
	  tcx_data = true;
	  break;

	case opt_print_summary:
	  print_summary = true;
	  break;

	case opt_print_laps:
	  print_laps = true;
	  break;

	case opt_print_points:
	  print_points = true;
	  break;

	case opt_print_smoothed:
	  print_smoothed = atoi(opt_arg);
	  break;

	case opt_print_date:
	  if (opt_arg != nullptr)
	    print_date = opt_arg;
	  else
	    print_date = "%a, %d %b %Y %H:%M:%S %z";
	  break;

	case opt_global_time:
	  global_time = true;
	  break;

	default:
	  print_usage(args);
	  exit(1);
	}
    }

  for (const std::string &s : args.args())
    {
      gps::activity activity;

      if (fit_data)
	activity.read_fit_file(s.c_str());
      else if (tcx_data)
	activity.read_tcx_file(s.c_str());
      else
	activity.read_file(s.c_str());

      if (print_date)
	{
	  time_t d = (time_t) activity.start_time();
	  if (d == 0)
	    continue;

	  struct tm tm = {0};
	  if (global_time)
	    gmtime_r(&d, &tm);
	  else
	    localtime_r(&d, &tm);

	  char buf[1024];
	  strftime(buf, sizeof(buf), print_date, &tm);

	  printf("%s\n", buf);
	}

      if (print_summary)
	activity.print_summary(stdout);

      if (print_laps)
	{
	  fputc('\n', stdout);
	  activity.print_laps(stdout);
	}

      if (print_points)
	{
	  printf("\nRAW track data:\n\n");
	  activity.print_points(stdout);
	}

      if (print_smoothed > 0)
	{
	  gps::activity smoothed;
	  smoothed.smooth(activity, print_smoothed);

	  printf("\nSmoothed track data (%ds):\n\n", print_smoothed);
	  smoothed.print_points(stdout);
	}
    }

  return 0;
}
