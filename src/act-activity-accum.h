// -*- c-style: gnu -*-

#ifndef ACT_ACTIVITY_ACCUM_H
#define ACT_ACTIVITY_ACCUM_H

#include "act-types.h"

namespace act {

class activity;

class activity_accum
{
  int _count;

  struct value_accum
    {
      int samples;
      double sum;
      double sum_sq;
      double min;
      double max;

      value_accum();
      void add(double x);

      double get_total() const;
      double get_mean() const;
      double get_sdev() const;
      double get_min() const;
      double get_max() const;
    };

  enum accum_id
    {
      accum_distance,
      accum_duration,
      accum_speed,
      accum_max_speed,
      accum_average_hr,
      accum_max_hr,
      accum_resting_hr,
      accum_calories,
      accum_weight,
      accum_effort,
      accum_quality,
      accum_temperature,
      accum_dew_point
    };

  enum {accum_count = accum_dew_point+1};

  value_accum _accum[accum_count];

public:
  activity_accum();

  void add(const activity &a);

  void printf(const char *format, const char *key) const;

private:
  void print_expansion(const char *name, const char *arg, const char *key,
    int field_width) const;
};

// implementation details

} // namespace act

#endif /* ACT_ACTIVITY_ACCUM_H */
