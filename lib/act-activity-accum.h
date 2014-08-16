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

#ifndef ACT_ACTIVITY_ACCUM_H
#define ACT_ACTIVITY_ACCUM_H

#include "act-types.h"

#include <vector>

namespace act {

class activity;
class output_table;

class activity_accum
{
public:
  enum class accum_field
    {
      distance,
      duration,
      speed,
      max_speed,
      avg_hr,
      max_hr,
      resting_hr,
      avg_cadence,
      max_cadence,
      avg_stance_time,
      avg_stance_ratio,
      avg_vertical_oscillation,
      avg_stride_length,
      calories,
      training_effect,
      weight,
      effort,
      quality,
      points,
      temperature,
      dew_point
    };

private:
  struct value_accum
    {
      accum_field field;
 
      int samples;
      double sum;
      double sum_sq;
      double min;
      double max;

      explicit value_accum(accum_field field);
      explicit value_accum(const value_accum &rhs) = default;

      void add(double x);

      double get_total() const;
      double get_mean() const;
      double get_sdev() const;
      double get_min() const;
      double get_max() const;
    };

  std::vector<value_accum> _accum;
  int _count;

public:
  static bool field_by_name(const char *name, accum_field &ret);
  static std::vector<accum_field> format_fields(const char *format);

  activity_accum(const std::vector<accum_field> &fields);

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
