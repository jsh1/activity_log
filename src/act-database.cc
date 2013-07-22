// -*- c-style: gnu -*-

#include "act-database.h"

#include "act-config.h"
#include "act-format.h"
#include "act-util.h"

#include <algorithm>

namespace act {

database::database()
{
  read_activities();
}

void
database::read_activities()
{
  _items.clear();

  map_directory_files(shared_config().activity_dir(),
		      read_activities_callback, this);

  std::sort(_items.begin(), _items.end(),
	    [] (const item &a, const item &b) {
	      return a.date() > b.date();
	    });
}

void
database::read_activities_callback(const char *path, void *ctx)
{
  database *db = static_cast<database *>(ctx);

  std::shared_ptr<activity_storage> storage (new activity_storage);
  storage->read_file(path);

  const std::string *date = storage->field_ptr("Date");
  if (!date)
    return;

  db->_items.resize(db->_items.size() + 1);
  item &it = db->_items.back();

  it._path = path;
  parse_date_time(*date, &it._date, nullptr);

  using std::swap;
  swap(it._storage, storage);
}

void
database::copy_items(std::vector<item_ref> &result,
  const std::vector<date_range> &dates, size_t skip, size_t max_count)
{
  result.clear();

  /* FIXME: this blows. */

  for (auto &it : _items)
    {
      bool matched = false;

      for (const auto &range : dates)
	{
	  if (range.contains(it.date()))
	    {
	      matched = true;
	      break;
	    }
	}

      if (!matched)
	continue;

      if (skip != 0)
	{
	  skip--;
	  continue;
	}

      result.push_back(&it);

      if (--max_count == 0)
	break;
    }
}

} // namespace act
