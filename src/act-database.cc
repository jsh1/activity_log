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
database::execute_query(const query &q, std::vector<item_ref> &result)
{
  result.clear();

  /* FIXME: this blows. */

  size_t to_skip = q.skip_count();
  size_t to_add = q.max_count();

  for (auto &it : _items)
    {
      bool matched = false;

      for (const auto &range : q.date_ranges())
	{
	  if (range.contains(it.date()))
	    {
	      matched = true;
	      break;
	    }
	}

      if (!matched)
	continue;

      if (q.term() && !(*q.term())(it))
	continue;

      if (to_skip != 0)
	{
	  to_skip--;
	  continue;
	}

      result.push_back(&it);

      if (--to_add == 0)
	break;
    }
}

database::not_term::not_term(const std::shared_ptr<const query_term> &t)
: term(t)
{
}

bool
database::not_term::operator() (const item &it) const
{
  return !(*term)(it);
}

database::and_term::and_term()
{
}

database::and_term::and_term(const std::shared_ptr<const query_term> &l,
			     const std::shared_ptr<const query_term> &r)
{
  terms.push_back(l);
  terms.push_back(r);
}

void
database::and_term::add_term(const std::shared_ptr<const query_term> &t)
{
  terms.push_back(t);
}

bool
database::and_term::operator() (const item &it) const
{
  for (const auto &t : terms)
    if (!(*t)(it))
      return false;

  return true;
}

database::or_term::or_term()
{
}

database::or_term::or_term(const std::shared_ptr<const query_term> &l,
			   const std::shared_ptr<const query_term> &r)
{
  terms.push_back(l);
  terms.push_back(r);
}

void
database::or_term::add_term(const std::shared_ptr<const query_term> &t)
{
  terms.push_back(t);
}

bool
database::or_term::operator() (const item &it) const
{
  for (const auto &t : terms)
    if ((*t)(it))
      return true;

  return false;
}

database::grep_term::grep_term(const std::string &f, const std::string &re)
: field(f),
  regexp(re)
{
  status = regcomp(&compiled, regexp.c_str(), REG_EXTENDED | REG_ICASE);
}

bool
database::grep_term::operator()(const item &it) const
{
  if (status != 0)
    return false;

  if (const std::string *str = it.storage()->field_ptr(field))
    {
      if (regexp.size() == 0)
	return true;

      if (regexec(&compiled, str->c_str(), 0, nullptr, 0) == 0)
	return true;
    }

  return false;
}

} // namespace act
