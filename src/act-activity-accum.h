// -*- c-style: gnu -*-

#ifndef ACT_ACTIVITY_ACCUM_H
#define ACT_ACTIVITY_ACCUM_H

#include "act-types.h"

namespace act {

class activity;
class output_table;

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

  enum class accum_id
    {
      distance,
      duration,
      speed,
      max_speed,
      average_hr,
      max_hr,
      resting_hr,
      calories,
      weight,
      effort,
      quality,
      temperature,
      dew_point
    };

  enum {accum_count = static_cast<int>(accum_id::dew_point)+1};

  value_accum _accum[accum_count];

public:
  activity_accum();

  void add(const activity &a);

  void printf(const char *format, const char *key) const;

  void print_row(output_table &out, const char *format, const char *key) const;

private:
  bool get_field_value(const char *name, const char *arg,
    field_data_type &type, double &value) const;
  void print_expansion(const char *name, const char *arg,
    const char *key, int field_width) const;
};

// implementation details

} // namespace act

#endif /* ACT_ACTIVITY_ACCUM_H */
