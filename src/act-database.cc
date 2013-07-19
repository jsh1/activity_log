// -*- c-style: gnu -*-

#include "act-database.h"

#include "act-config.h"
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
  _activities.clear();

  map_directory_files(shared_config().activity_dir(),
		      read_activities_callback, this);

  struct compare
    {
      bool operator() (const db_activity &a, const db_activity &b)
        {
	  return !(a.data->date() < b.data->date());
	}
    };

  compare cmp;
  std::sort(_activities.begin(), _activities.end(), cmp);
}

void
database::read_activities_callback(const char *path, void *ctx)
{
  std::unique_ptr<activity> a (new activity);

  a->read_file(path);

  if (a->date() == 0)
    return;

  database *db = static_cast<database *>(ctx);

  db->_activities.resize(db->_activities.size() + 1);
  db_activity &dba = db->_activities.back();
  dba.path = path;

  using std::swap;
  swap(dba.data, a);
}

void
database::enumerate_activities(std::vector<activity_ref> &result,
  const std::vector<date_range> &dates, size_t skip, size_t max_count)
{
  result.clear();

  /* FIXME: this blows. */

  for (const auto &it : _activities)
    {
      bool matched = false;

      for (const auto &range : dates)
	{
	  if (range.contains(it.data->date()))
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

      result.push_back(it.data.get());

      if (--max_count == 0)
	break;
    }
}

} // namespace act
