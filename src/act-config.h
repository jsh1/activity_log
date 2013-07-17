// -*- c-style: gnu -*-

#ifndef ACT_CONFIG_H
#define ACT_CONFIG_H

#include "base.h"

namespace activity_log {

class config
{
  const char *_activity_dir;
  const char *_gps_file_dir;

public:
  config();
  ~config();

  const char *activity_dir() const;
  const char *gps_file_dir() const;

  void find_new_gps_files(std::vector<std::string> &files) const;

  bool find_gps_file(std::string &str) const;

  void edit_file(const char *filename);
};

const config &shared_config();

// implementation details

inline const char *
config::activity_dir() const
{
  return _activity_dir;
}

inline const char *
config::gps_file_dir() const
{
  return _gps_file_dir;
}

} // namespace activity_log

#endif /* ACT_CONFIG_H */
