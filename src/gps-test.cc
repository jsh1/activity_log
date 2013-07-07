// -*- c-style: gnu -*-

#include "gps-activity.h"
#include "fit-parser.h"
#include "tcx-parser.h"

#include <getopt.h>
#include <math.h>

using namespace activity_log;

#define MILES_PER_METER 0.000621371192
#define FEET_PER_METER 3.2808399
#define MINUTES_PER_MILE(x) ((1. / (x)) * (1. / (MILES_PER_METER * 60.)))
#define SECS_PER_MILE(x) ((1. /  (x)) * (1. / MILES_PER_METER))

static void
format_duration(char *buf, size_t bufsiz, double dur, bool include_frac)
{
  if (dur > 3600)
    snprintf(buf, bufsiz, "%d:%02d:%02d", (int) floor(dur/3600),
	     (int) fmod(floor(dur/60),60), (int) fmod(dur, 60));
  else if (dur > 60)
    snprintf(buf, bufsiz, "%d:%02d", (int) floor(dur/60), (int) fmod(dur, 60));
  else
    snprintf(buf, bufsiz, "%d", (int) dur);

  if (include_frac)
    {
      double frac = dur - floor(dur);

      if (frac > 1e-4)
	{
	  size_t len = strlen(buf);
	  buf += len;
	  bufsiz -= len;

	  snprintf(buf, bufsiz, ".%02d", (int) floor(frac * 10 + .5));
	}
    }
}

template<typename T> static void
print_summary(const T &a)
{
  char buf[256];

  time_t time = a.time();
  struct tm tm;
  localtime_r(&time, &tm);

  strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S %Z", &tm);
  printf("Date:\t\t%s\n", buf);

  format_duration(buf, sizeof(buf), a.duration(), true);
  printf("Duration:\t%s\n", buf);

  printf("Distance:\t%.2f miles\n", a.distance() * MILES_PER_METER);

  format_duration(buf, sizeof(buf), SECS_PER_MILE(a.avg_speed()), false);
  printf("Pace:\t\t%s / mile\n", buf);

  format_duration(buf, sizeof(buf), SECS_PER_MILE(a.max_speed()), false);
  printf("Max Pace:\t%s / mile\n", buf);

  if (a.avg_heart_rate() != 0)
    printf("Avg HR:\t\t%d\n", (int) a.avg_heart_rate());
  if (a.max_heart_rate() != 0)
    printf("Max HR:\t\t%d\n", (int) a.max_heart_rate());

  if (a.calories() != 0)
    printf("Calories:\t%g\n", a.calories());
}

static void
print_laps(const gps::activity &a)
{
  int lap_idx = 0;
  for (std::vector<gps::activity::lap>::const_iterator it = a.laps().begin();
       it != a.laps().end(); it++, lap_idx++)
    {
      printf("== Lap %d ==\n", lap_idx + 1);
      print_summary(*it);
    }
}

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

      if (opt_print_summary)
	print_summary(test_activity);
      if (opt_print_laps)
	print_laps(test_activity);
    }

  return 0;
}
