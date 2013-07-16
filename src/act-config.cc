// -*- c-style: gnu -*-

#include "act-config.h"

namespace activity_log {

config::config()
: _activity_dir(getenv("ACTIVITY_LOG_DIR")),
  _gps_file_dir(getenv("ACTIVITY_GPS_DIR"))
{
  if (!_activity_dir)
    {
      fprintf(stderr, "You need to set $ACTIVITY_LOG_DIR.\n");
      exit(1);
    }
}

config::~config()
{
}

const config &
shared_config()
{
  static const config *cfg = new config();
  return cfg;
}

} // namespace activity_log
