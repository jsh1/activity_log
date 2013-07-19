// -*- c-style: gnu -*-

#ifndef ACT_DATABASE_H
#define ACT_DATABASE_H

#include "act-activity.h"

#include <vector>

namespace act {

class database : public uncopyable
{
  struct db_activity
    {
      std::string path;
      std::unique_ptr<activity> data;
    };

  std::vector<db_activity> _activities;

public:
  database();

  typedef activity *activity_ref;

  void enumerate_activities(std::vector<activity_ref> &result,
    const std::vector<date_range> &dates, size_t skip = 0,
    size_t max_count = SIZE_T_MAX);

private:
  void read_activities();

  static void read_activities_callback(const char *path, void *ctx);
};

} // namespace act

#endif /* ACT_DATABASE_H */
