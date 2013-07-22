// -*- c-style: gnu -*-

#include "act-gps-activity.h"

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
  printf("reading %s\n", path);
  fit_parser parser(*this);
  parser.parse_file(path);
  return !parser.had_error();
}

bool
activity::read_tcx_file(const char *path)
{
  printf("reading %s\n", path);
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

} // namespace gps
} // namespace act
