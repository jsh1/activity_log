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

#ifndef ACT_ACTIVITY_H
#define ACT_ACTIVITY_H

#include "act-activity-storage.h"

#include "act-types.h"
#include "act-gps-activity.h"

#include <memory>

namespace act {

class activity : public uncopyable
{
public:
  activity(activity_storage_ref storage);

  activity_storage_ref storage();
  const_activity_storage_ref storage() const;

  bool make_filename(std::string &filename) const;

  void printf(const char *format) const;

  const std::string &body() const;
  std::string &body();

  std::string &operator[] (const char *name);
  std::string &operator[] (const std::string &name);
  const std::string *field_ptr (const char *name) const;
  const std::string *field_ptr (const std::string &name) const;

  double field_value(field_id id) const;
  const std::vector<std::string> *field_keywords_ptr(field_id id) const;
  unit_type field_unit(field_id id) const;

  const gps::activity *gps_data() const;

  time_t date() const;
  double duration() const;
  double elapsed_time() const;

  double distance() const;
  unit_type distance_unit() const;

  double ascent() const;
  unit_type ascent_unit() const;

  double descent() const;
  unit_type descent_unit() const;

  double speed() const;
  unit_type speed_unit() const;

  double max_speed() const;
  unit_type max_speed_unit() const;

  double effort() const;
  double quality() const;
  double points() const;

  double resting_hr() const;
  double average_hr() const;
  double max_hr() const;

  double calories() const;

  double weight() const;
  unit_type weight_unit() const;

  const std::vector<std::string> &equipment() const;

  double temperature() const;
  unit_type temperature_unit() const;

  double dew_point() const;
  unit_type dew_point_unit() const;

  const std::vector<std::string> &weather() const;

  const std::vector<std::string> &keywords() const;

  double vdot() const;

private:
  activity_storage_ref _storage;

  mutable std::unique_ptr<gps::activity> _gps_data;

  // Split the properties into groups, helps avoid parsing the GPS
  // file until we really need it.

  enum field_groups
    {
      group_timing = 1U << 0,
      group_physiological = 1U << 1,
      group_gps_extended = 1U << 2,
      group_other = 1U << 3,
      group_all = 0xffU,
    };

  // group_timing

  mutable time_t _date;
  mutable double _duration;
  mutable double _distance;
  mutable unit_type _distance_unit;
  mutable double _speed;
  mutable unit_type _speed_unit;

  // group_physiological

  mutable double _resting_hr;
  mutable double _average_hr;
  mutable double _max_hr;
  mutable double _calories;
  mutable double _weight;
  mutable unit_type _weight_unit;

  // group_gps_extended

  mutable double _elapsed_time;
  mutable double _ascent;
  mutable unit_type _ascent_unit;
  mutable double _descent;
  mutable unit_type _descent_unit;
  mutable double _max_speed;
  mutable unit_type _max_speed_unit;

  // group_other

  mutable double _effort;
  mutable double _quality;
  mutable double _points;
  mutable double _temperature;
  mutable double _dew_point;
  mutable unit_type _temperature_unit;
  mutable unit_type _dew_point_unit;

  mutable std::vector<std::string> _equipment;
  mutable std::vector<std::string> _weather;
  mutable std::vector<std::string> _keywords;

  mutable unsigned int _invalid_groups;
  mutable uint32_t _seed;

  void validate_cached_values(unsigned int groups) const;

  void print_expansion(FILE *fh, const char *name, const char *arg,
    int field_width) const;
  void print_field(FILE *fh, const char *name, const char *arg) const;
};

// implementation details

inline activity_storage_ref
activity::storage()
{
  return _storage;
}

inline const_activity_storage_ref
activity::storage() const
{
  return _storage;
}

inline const std::string &
activity::body() const
{
  return _storage->body();
}

inline std::string &
activity::body()
{
  return _storage->body();
}

inline std::string &
activity::operator[] (const char *name)
{
  return (*_storage)[name];
}

inline std::string &
activity::operator[] (const std::string &name)
{
  return (*_storage)[name];
}

inline const std::string *
activity::field_ptr(const char *name) const
{
  return _storage->field_ptr(name);
}

inline const std::string *
activity::field_ptr(const std::string &name) const
{
  return _storage->field_ptr(name);
}

} // namespace act

#endif /* ACT_ACTIVITY_H */
