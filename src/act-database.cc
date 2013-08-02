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

      if (q.term())
	{
	  activity a (it.storage());
	  if (!(*q.term())(a))
	    continue;
	}

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
database::not_term::operator() (const activity &a) const
{
  return !(*term)(a);
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
database::and_term::operator() (const activity &a) const
{
  for (const auto &t : terms)
    if (!(*t)(a))
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
database::or_term::operator() (const activity &a) const
{
  for (const auto &t : terms)
    if ((*t)(a))
      return true;

  return false;
}

database::matches_term::matches_term(const std::string &f,
				     const std::string &re)
: field(f),
  regexp(re)
{
  status = regcomp(&compiled, regexp.c_str(), REG_EXTENDED | REG_ICASE);
}

bool
database::matches_term::operator()(const activity &a) const
{
  if (status != 0)
    return false;

  if (const std::string *str = a.storage()->field_ptr(field))
    {
      if (regexec(&compiled, str->c_str(), 0, nullptr, 0) == 0)
	return true;
    }

  return false;
}

database::defines_term::defines_term(const std::string &f)
: field(f)
{
}

bool
database::defines_term::operator()(const activity &a) const
{
  return a.storage()->field_ptr(field) != nullptr;
}

database::contains_term::contains_term(const std::string &f,
				       const std::string &k)
: field(f),
  keyword(k)
{
}

bool
database::contains_term::operator()(const activity &a) const
{
  if (const std::string *str = a.storage()->field_ptr(field))
    {
      std::vector<std::string> keys;
      if (parse_keywords(*str, &keys))
	{
	  for (const auto &it : keys)
	    {
	      if (strcasecmp(it.c_str(), keyword.c_str()) == 0)
		return true;
	    }
	}
    }

  return false;
}

database::compare_term::compare_term(const std::string &f,
				     compare_op o, double r)
: field(f),
  op(o),
  rhs(r)
{
}

bool
database::compare_term::operator()(const activity &a) const
{
  field_id id = lookup_field_id(field.c_str());

  field_data_type type = lookup_field_data_type(id);
  if (type == type_string)
    type = type_number;

  /* Use activity to read known fields, e.g. this ensures we fill in
     missing fields from any GPS file. */

  double lhs;
  if (id != field_custom)
    {
      lhs = a.field_value(id);
      if (lhs == 0)
	return false;
    }
  else
    {
      const std::string *str = a.storage()->field_ptr(field);
      if (!str || !parse_value(*str, type, &lhs, nullptr))
	return false;
    }

  /* FIXME: hack -- comparison order needs to be inverted for pace, as
     the values are converted to speed (1/pace). */

  double rhs = this->rhs;
  if (type == type_pace)
    lhs = 1/lhs, rhs = 1/rhs;

  switch (op)
    {
    case op_equal:
      return lhs == rhs;
    case op_not_equal:
      return lhs != rhs;
    case op_greater:
      return lhs > rhs;
    case op_greater_or_equal:
      return lhs >= rhs;
    case op_less:
      return lhs < rhs;
    case op_less_or_equal:
      return lhs <= rhs;
    }

  return false;
}

database::grep_term::grep_term(const std::string &re)
: regexp(re)
{
  status = regcomp(&compiled, regexp.c_str(), REG_EXTENDED | REG_ICASE);
}

bool
database::grep_term::operator()(const activity &a) const
{
  if (status != 0)
    return false;

  return regexec(&compiled, a.body().c_str(), 0, nullptr, 0) == 0;
}

} // namespace act
