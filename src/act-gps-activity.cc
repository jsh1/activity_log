// -*- c-style: gnu -*-

#include "act-gps-activity.h"

#include "act-format.h"
#include "act-gps-fit-parser.h"
#include "act-gps-tcx-parser.h"
#include "act-util.h"

#include <math.h>

namespace act {
namespace gps {

activity::activity()
: _sport(sport_unknown),
  _time(0),
  _duration(0),
  _distance(0),
  _avg_speed(0),
  _max_speed(0),
  _calories(0),
  _avg_heart_rate(0),
  _max_heart_rate(0)
{
}

bool
activity::read_file(const char *path)
{
  if (path_has_extension(path, "fit"))
    return read_fit_file(path);
  else if (path_has_extension(path, "tcx"))
    return read_tcx_file(path);
  else
    return false;
}

bool
activity::read_fit_file(const char *path)
{
  fit_parser parser(*this);
  parser.parse_file(path);
  return !parser.had_error();
}

bool
activity::read_tcx_file(const char *path)
{
  tcx_parser parser(*this);
  parser.parse_file(path);
  return !parser.had_error();
}

void
activity::update_summary()
{
  _time = 0;
  _duration = 0;
  _distance = 0;
  _avg_speed = 0;
  _max_speed = 0;
  _calories = 0;
  _avg_heart_rate = 0;
  _max_heart_rate = 0;

  if (laps().size() < 1)
    return;

  _time = laps()[0].time();

  for (std::vector<activity::lap>::const_iterator it = laps().begin();
       it != laps().end(); it++)
    {
      _duration += it->duration();
      _distance += it->distance();
      _max_speed = fmax(_max_speed, it->max_speed());
      _calories += it->calories();
      _avg_heart_rate += it->avg_heart_rate() * it->duration();
      _max_heart_rate = fmax(_max_heart_rate, it->max_heart_rate());
    }

  _avg_speed = _distance / _duration;
  _avg_heart_rate = _avg_heart_rate / _duration;
}

void
activity::print_summary(FILE *fh) const
{
  std::string tem;

  format_date_time(tem, (time_t) time());
  fprintf(fh, "Date: %s\n", tem.c_str());
  tem.clear();

  format_duration(tem, duration());
  fprintf(fh, "Duration: %s\n", tem.c_str());
  tem.clear();

  format_distance(tem, distance(), unit_miles);
  fprintf(fh, "Distance: %s\n", tem.c_str());
  tem.clear();

  format_pace(tem, avg_speed(), unit_seconds_per_mile);
  fprintf(fh, "Pace: %s\n", tem.c_str());
  tem.clear();

  format_pace(tem, max_speed(), unit_seconds_per_mile);
  fprintf(fh, "Max-Pace: %s\n", tem.c_str());
  tem.clear();

  if (avg_heart_rate() != 0)
    fprintf(fh, "Avg-HR: %d\n", (int) avg_heart_rate());
  if (max_heart_rate() != 0)
    fprintf(fh, "Max-HR: %d\n", (int) max_heart_rate());

  if (calories() != 0)
    fprintf(fh, "Calories: %g\n", calories());
}

void
activity::print_laps(FILE *fh) const
{
  if (laps().size() == 0)
    return;

  bool has_hr = avg_heart_rate() != 0;

  if (has_hr)
    {
      fprintf(fh, "    %-3s  %8s  %6s  %5s %5s  %3s %3s  %4s\n", "Lap", "Time",
	      "Dist.", "Pace", "Max", "HR", "Max",
	      "Cal.");
    }
  else
    {
      fprintf(fh, "    %-3s  %8s  %6s  %5s %5s  %4s\n", "Lap", "Time",
	      "Dist.", "Pace", "Max", "Cal.");
    }

  const double miles_per_meter = 0.000621371192;

  int lap_idx = 0;
  for (const auto &it : laps())
    {
      std::string dur;
      format_time(dur, it.duration(), true, "");

      std::string pace, max_pace;
      format_time(pace, 1/(it.avg_speed() * miles_per_meter), false, "");
      format_time(max_pace, 1/(it.max_speed() * miles_per_meter), false, "");

      std::string avg_hr, max_hr;
      if (has_hr)
	{
	  format_number(avg_hr, it.avg_heart_rate());
	  format_number(max_hr, it.max_heart_rate());
	}

      std::string cal;
      if (it.calories() != 0)
	format_number(cal, it.calories());

      if (has_hr)
	{
	  fprintf(fh, "    %-3d  %8s  %6.2f  %5s %5s  %3s %3s  %4s\n",
		  lap_idx + 1, dur.c_str(), it.distance() * miles_per_meter,
		  pace.c_str(), max_pace.c_str(), avg_hr.c_str(),
		  max_hr.c_str(), cal.c_str());
	}
      else
	{
	  fprintf(fh, "    %-3d  %8s  %6.2f  %5s %5s  %4s\n",
		  lap_idx + 1, dur.c_str(), it.distance() * miles_per_meter,
		  pace.c_str(), max_pace.c_str(), cal.c_str());
	}

      lap_idx++;
    }

  if (lap_idx > 0)
    fputc('\n', fh);
}

} // namespace gps
} // namespace act
