// -*- c-style: gnu -*-

#include "act-intensity-points.h"

#include "act-config.h"
#include "act-gps-activity.h"

#include <xlocale.h>

namespace act {

namespace {

double
vvo2_max(double vdot)
{
  return 2.8859 + .0686 * (vdot - 29);
}

double
points(double v_max, double v, double t)
{
  // from Daniels' Running Formula, 2nd edition, pp. 39-40. Fitting
  // a curve to the table gives approximately: f(x) = (x/100)^4.

  double x = v / v_max;
  x = x * x;
  x = x * x;
  return x * t * (1. / 60.);
}

} // anonymous namespace

double
calculate_points(double v, double t)
{
  double vdot = shared_config().vdot();
  if (vdot == 0)
    return 0;

  return points(vvo2_max(vdot), v, t);
}

double
calculate_points(const gps::activity &track)
{
  if (!track.has_speed())
    return 0;

  double vdot = shared_config().vdot();
  if (vdot == 0)
    return 0;

  double vmax = vvo2_max(vdot);

  double total = 0;

  for (const auto &it : track.laps())
    {
      total += points(vmax, it.avg_speed, it.duration);
    }

  return total;
}

} // namespace act
