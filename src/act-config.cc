// -*- c-style: gnu -*-

#include "act-config.h"

namespace act {

config::config()
: _activity_dir(getenv("ACT_DIR")),
  _gps_file_dir(getenv("ACT_GPS_DIR"))
{
  if (!_activity_dir)
    {
      fprintf(stderr, "You need to set $ACT_DIR.\n");
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
  return *cfg;
}

void
config::find_new_gps_files(std::vector<std::string> &files) const
{
}

bool
config::find_gps_file(std::string &str) const
{
  return false;
}

void
config::edit_file(const char *filename) const
{
  const char *editor = getenv("ACT_EDITOR");
  if (!editor)
    editor = getenv("VISUAL");
  if (!editor)
    editor = getenv("EDITOR");

  char *command = 0;
  asprintf(&command, "\'%s\' '%s'", editor, filename);

  if (command)
    {
      system(command);
      free(command);
    }
}

} // namespace act
