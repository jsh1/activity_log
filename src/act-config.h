// -*- c-style: gnu -*-

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

  distance_unit _default_distance_unit;
  pace_unit _default_pace_unit;
  speed_unit _default_speed_unit;
  temperature_unit _default_temperature_unit;

  int _start_of_week;

  bool _silent;
  bool _verbose;

public:
  config();
  ~config();

  const char *activity_dir() const;
  const char *gps_file_dir() const;

  distance_unit default_distance_unit() const;
  pace_unit default_pace_unit() const;
  speed_unit default_speed_unit() const;
  temperature_unit default_temperature_unit() const;

  // delta from sunday, i.e. -1 = saturday, +1 = monday.

  int start_of_week() const;

  bool silent() const;
  bool verbose() const;

  void find_new_gps_files(std::vector<std::string> &files) const;
  bool find_gps_file(std::string &str) const;

  void edit_file(const char *filename) const;
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

inline distance_unit
config::default_distance_unit() const
{
  return _default_distance_unit;
}

inline pace_unit
config::default_pace_unit() const
{
  return _default_pace_unit;
}

inline speed_unit
config::default_speed_unit() const
{
  return _default_speed_unit;
}

inline temperature_unit
config::default_temperature_unit() const
{
  return _default_temperature_unit;
}

inline int
config::start_of_week() const
{
  return _start_of_week;
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
