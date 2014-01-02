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

#ifndef ACT_CONFIG_H
#define ACT_CONFIG_H

#include "act-base.h"
#include "act-types.h"

#include <string>
#include <vector>

namespace act {

class config
{
  std::string _activity_dir;
  std::string _gps_file_dir;
  std::vector<std::string> _gps_file_path;

  unit_type _default_distance_unit;
  unit_type _default_height_unit;
  unit_type _default_pace_unit;
  unit_type _default_speed_unit;
  unit_type _default_temperature_unit;
  unit_type _default_weight_unit;
  unit_type _default_efficiency_unit;

  int _start_of_week;

  int _resting_hr;
  int _max_hr;

  double _vdot;

  bool _silent;
  bool _verbose;

public:
  config();
  ~config();

  const char *activity_dir() const;
  const char *gps_file_dir() const;
  const std::vector<std::string> &gps_file_path() const;

  unit_type default_distance_unit() const;
  unit_type default_height_unit() const;
  unit_type default_pace_unit() const;
  unit_type default_speed_unit() const;
  unit_type default_temperature_unit() const;
  unit_type default_weight_unit() const;
  unit_type default_efficiency_unit() const;

  // delta from sunday, i.e. -1 = saturday, +1 = monday.

  int start_of_week() const;

  int resting_hr() const;
  int max_hr() const;

  double vdot() const;

  bool silent() const;
  bool verbose() const;

  void find_new_gps_files(std::vector<std::string> &files) const;
  bool find_gps_file(std::string &str) const;

  void edit_file(const char *filename) const;

private:
  void read_config_file(const char *path);
  void set_start_of_week(const char *value);
  void append_gps_file_path(const char *path_str, bool tilde_expand);
};

const config &shared_config();

// implementation details

inline const char *
config::activity_dir() const
{
  return _activity_dir.c_str();
}

inline const char *
config::gps_file_dir() const
{
  return _gps_file_dir.c_str();
}

inline const std::vector<std::string> &
config::gps_file_path() const
{
  return _gps_file_path;
}

inline unit_type
config::default_distance_unit() const
{
  return _default_distance_unit;
}

inline unit_type
config::default_height_unit() const
{
  return _default_height_unit;
}

inline unit_type
config::default_pace_unit() const
{
  return _default_pace_unit;
}

inline unit_type
config::default_speed_unit() const
{
  return _default_speed_unit;
}

inline unit_type
config::default_temperature_unit() const
{
  return _default_temperature_unit;
}

inline unit_type
config::default_weight_unit() const
{
  return _default_weight_unit;
}

inline unit_type
config::default_efficiency_unit() const
{
  return _default_efficiency_unit;
}

inline int
config::start_of_week() const
{
  return _start_of_week;
}

inline int
config::resting_hr() const
{
  return _resting_hr;
}

inline int
config::max_hr() const
{
  return _max_hr;
}

inline double
config::vdot() const
{
  return _vdot;
}

inline bool
config::silent() const
{
  return _silent;
}

inline bool
config::verbose() const
{
  return _verbose;
}

} // namespace act

#endif /* ACT_CONFIG_H */
