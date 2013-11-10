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

#ifndef ACT_FORMAT_H
#define ACT_FORMAT_H

#include "act-base.h"
#include "act-types.h"

#include <string>
#include <vector>

#include <time.h>

namespace act {

// string conversion functions

void format_date_time(std::string &str, time_t date);
void format_date_time(std::string &str, time_t date, const char *format);
void format_time(std::string &str, double dur, bool include_frac,
  const char *suffix);
void format_duration(std::string &str, double dur);
void format_number(std::string &str, double value);
void format_distance(std::string &str, double dist, unit_type unit);
void format_pace(std::string &str, double pace, unit_type unit);
void format_speed(std::string &str, double speed, unit_type unit);
void format_temperature(std::string &str, double temp, unit_type unit);
void format_weight(std::string &str, double weight, unit_type unit);
void format_heart_rate(std::string &str, double value, unit_type unit);
void format_fraction(std::string &str, double frac);
void format_keywords(std::string &str, const std::vector<std::string> &keys);

void format_value(std::string &str, field_data_type type, double value,
  unit_type unit);

bool parse_date_time(const std::string &str, time_t *date_ptr,
  time_t *range_ptr);
bool parse_date_range(const std::string &str, time_t *date_ptr,
  time_t *range_ptr);
bool parse_date_interval(const std::string &str, date_interval *interval_ptr);
bool parse_duration(const std::string &str, double *dur_ptr);
bool parse_number(const std::string &str, double *value_ptr);
bool parse_distance(const std::string &str, double *dist_ptr,
  unit_type *unit_ptr);
bool parse_pace(const std::string &str, double *pace_ptr,
  unit_type *unit_ptr);
bool parse_speed(const std::string &str, double *speed_ptr,
  unit_type *unit_ptr);
bool parse_temperature(const std::string &str, double *temp_ptr,
  unit_type *unit_ptr);
bool parse_weight(const std::string &str, double *weight_ptr,
  unit_type *unit_ptr);
bool parse_heart_rate(const std::string &str, double *value_ptr,
  unit_type *unit_ptr);
bool parse_fraction(const std::string &str, double *frac_ptr);
bool parse_keywords(const std::string &str,
  std::vector<std::string> *keys_ptr);

bool parse_value(const std::string &str, field_data_type type,
  double *value_ptr, unit_type *unit_ptr);
bool parse_unit(const std::string &str, field_data_type type, unit_type &unit);

} // namespace act

#endif /* ACT_FORMAT_H */
