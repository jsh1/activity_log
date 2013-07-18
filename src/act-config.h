// -*- c-style: gnu -*-

#ifndef ACT_CONFIG_H
#define ACT_CONFIG_H

#include "act-base.h"

#include <string>
#include <vector>

namespace act {

class config
{
  std::string _activity_dir;
  std::string _gps_file_dir;

public:
  config();
  ~config();

  const char *activity_dir() const;
  const char *gps_file_dir() const;

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

} // namespace act

#endif /* ACT_CONFIG_H */
