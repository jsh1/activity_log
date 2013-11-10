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

#include "act-intensity-points.h"

#include "act-config.h"
#include "act-gps-activity.h"

#include <xlocale.h>

namespace act {

namespace {

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
vvo2_max(double vdot)
{
  return 2.8859 + .0686 * (vdot - 29);
}

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
      total += points(vmax, it.avg_speed, it.total_duration);
    }

  return total;
}

} // namespace act
