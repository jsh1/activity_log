// -*- c-style: gnu -*-

#include "act-database.h"

#include "act-config.h"
#include "act-util.h"

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
}

void
database::read_activities_callback(const char *path, void *ctx)
{
  activity a;
  a.read_file(path);

  if (a.date() == 0)
    return;

  database *db = static_cast<database *>(ctx);

  db->_activities.resize(db->_activities.size() + 1);
  db_activity &dba = db->_activities.back();
  dba.path = path;
  std::swap(dba.data, a);
}

void
database::enumerate_activities(std::vector<activity_ref> &result,
  const std::vector<date_range> &dates, size_t skip, size_t max_count)
{
  result.clear();

  for (size_t i = 0; i < _activities.size(); i++)
    {
      if (skip != 0)
	{
	  skip--;
	  continue;
	}

      result.push_back(&_activities[i].data);

      if (--max_count == 0)
	break;
    }
}

} // namespace act
