// -*- c-style: gnu -*-

#include "act-gps-activity.h"
#include "act-gps-parser.h"
#include "act-gps-fit-parser.h"
#include "act-gps-tcx-parser.h"

#include <getopt.h>
#include <math.h>

using namespace act;

#define MILES_PER_METER 0.000621371192
#define FEET_PER_METER 3.2808399
#define MINUTES_PER_MILE(x) ((1. / (x)) * (1. / (MILES_PER_METER * 60.)))
#define SECS_PER_MILE(x) ((1. /  (x)) * (1. / MILES_PER_METER))

static void
format_duration(char *buf, size_t bufsiz, double dur, bool include_frac)
{
  if (!include_frac)
    dur = floor(dur + .5);

  if (dur > 3600)
    snprintf(buf, bufsiz, "%d:%02d:%02d", (int) floor(dur/3600),
	     (int) fmod(floor(dur/60),60), (int) fmod(dur, 60));
  else if (dur > 60)
    snprintf(buf, bufsiz, "%d:%02d", (int) floor(dur/60), (int) fmod(dur, 60));
  else
    snprintf(buf, bufsiz, "%d", (int) dur);

  double frac = dur - floor(dur);

  if (frac > 1e-4)
    {
      size_t len = strlen(buf);
      buf += len;
      bufsiz -= len;

      snprintf(buf, bufsiz, ".%02d", (int) floor(frac * 10 + .5));
    }
}

static void
print_summary(const gps::activity &a)
{
  char buf[256];

  time_t time = a.time();
  struct tm tm;
  localtime_r(&time, &tm);

  strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S %Z", &tm);
  printf("%16s: %s\n", "Date", buf);

  format_duration(buf, sizeof(buf), a.duration(), true);
  printf("%16s: %s\n", "Duration", buf);

  printf("%16s: %.2f miles\n", "Distance", a.distance() * MILES_PER_METER);

  format_duration(buf, sizeof(buf), SECS_PER_MILE(a.avg_speed()), false);
  printf("%16s: %s / mile\n", "Avg Pace", buf);

  format_duration(buf, sizeof(buf), SECS_PER_MILE(a.max_speed()), false);
  printf("%16s: %s / mile\n", "Max Pace", buf);

  if (a.avg_heart_rate() != 0)
    printf("%16s: %d\n", "Avg HR", (int) a.avg_heart_rate());
  if (a.max_heart_rate() != 0)
    printf("%16s: %d\n", "Max HR", (int) a.max_heart_rate());

  if (a.calories() != 0)
    printf("%16s: %g\n", "Calories", a.calories());
}

static void
print_laps(const gps::activity &a)
{
  printf("\n%-3s  %8s  %6s  %5s %5s  %3s %3s  %4s\n", "Lap", "Time",
	 "Dist.", "Pace", "Max", "HR", "Max",
	 "Cal.");

  int lap_idx = 0;
  for (std::vector<gps::activity::lap>::const_iterator it = a.laps().begin();
       it != a.laps().end(); it++, lap_idx++)
    {
      char dur_buf[8];
      format_duration(dur_buf, sizeof(dur_buf), it->duration(), true);

      char pace_buf[8], max_pace_buf[8];
      format_duration(pace_buf, sizeof(pace_buf),
		      SECS_PER_MILE(it->avg_speed()), false);
      format_duration(max_pace_buf, sizeof(max_pace_buf),
		      SECS_PER_MILE(it->max_speed()), false);

      char avg_hr_buf[8], max_hr_buf[8];
      if (it->avg_heart_rate() != 0)
	{
	  snprintf(avg_hr_buf, sizeof(avg_hr_buf), "%d",
		   (int) it->avg_heart_rate());
	  snprintf(max_hr_buf, sizeof(max_hr_buf), "%d",
		   (int) it->max_heart_rate());
	}
      else
	avg_hr_buf[0] = max_hr_buf[0] = 0;

      char cal_buf[8];
      if (it->calories() != 0)
	snprintf(cal_buf, sizeof(cal_buf), "%d", (int) it->calories());
      else
	cal_buf[0] = 0;

      printf("%-3d  %8s  %6.2f  %5s %5s  %3s %3s  %4s\n", lap_idx + 1, dur_buf,
	     it->distance() * MILES_PER_METER, pace_buf, max_pace_buf,
	     avg_hr_buf, max_hr_buf, cal_buf);
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
      else
	test_activity.read_file(argv[i]);

      if (opt_print_summary)
	print_summary(test_activity);
      if (opt_print_laps)
	print_laps(test_activity);
    }

  return 0;
}
