// -*- c-style: gnu -*-

#ifndef ACT_DATABASE_H
#define ACT_DATABASE_H

#include "act-activity.h"

#include <memory>
#include <vector>

namespace act {

class database : public uncopyable
{
  class item
    {
      friend class database;

      std::string _path;
      time_t _date;
      std::shared_ptr<activity_storage> _storage;

    public:
      const std::string &path() const {return _path;}

      time_t date() const {return _date;}

      std::shared_ptr<activity_storage> storage() {return _storage;}
      std::shared_ptr<const activity_storage> storage() const {
	return std::const_pointer_cast<const activity_storage> (_storage);}
    };

  std::vector<item> _items;

public:
  database();

  typedef item *item_ref;

  void copy_items(std::vector<item_ref> &result,
    const std::vector<date_range> &dates, size_t skip = 0,
    size_t max_count = SIZE_T_MAX);

private:
  void read_activities();

  static void read_activities_callback(const char *path, void *ctx);
};

} // namespace act

#endif /* ACT_DATABASE_H */
