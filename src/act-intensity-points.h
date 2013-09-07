// -*- c-style: gnu -*-

#ifndef ACT_INTENSITY_POINTS_H
#define ACT_INTENSITY_POINTS_H

#include "act-base.h"

namespace act {

namespace gps {
  class activity;
}

double calculate_points(double velocity, double duration);

double calculate_points(const gps::activity &track);

} // namespace act

#endif /* ACT_INTENSITY_POINTS_H */
