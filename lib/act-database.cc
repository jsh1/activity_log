/* -*- c-style: gnu -*-

   Copyright (c) 2013 John Harper <jsh@unfactored.org>

   Permission is hereby granted, free of charge, to any person
   obtaining a copy of this software and associated documentation files
   (the "Software"), to deal in the Software without restriction,
   including without limitation the rights to use, copy, modify, merge,
   publish, distribute, sublicense, and/or sell copies of the Software,
   and to permit persons to whom the Software is furnished to do so,
   subject to the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE. */

#include "act-database.h"

#include "act-config.h"
#include "act-format.h"
#include "act-util.h"

#include <algorithm>
#include <set>

#define COMPLETION_DAYS 100

namespace act {

database::database()
: _activity_dir(shared_config().activity_dir())
{
}

database::database(const database &rhs)
: _activity_dir(rhs._activity_dir),
  _items(rhs._items)
{
}

void
database::clear()
{
  _items.clear();
}

void
database::reload()
{
  _items.clear();

  map_directory_files(_activity_dir.c_str(), reload_callback, this);

  std::sort(_items.begin(), _items.end(),
	    [] (const item &a, const item &b) {
	      return a.date() > b.date();
	    });
}

void
database::reload_callback(const char *path, void *ctx)
{
  database *db = static_cast<database *>(ctx);

  activity_storage_ref storage = std::make_shared<activity_storage> ();

  if (!storage->read_file(path))
    return;

  storage->set_path(path);

  const std::string *date = storage->field_ptr("Date");
  if (date == nullptr)
    return;

  db->_items.resize(db->_items.size() + 1);
  item &it = db->_items.back();

  parse_date_time(*date, &it._date, nullptr);

  using std::swap;
  swap(it._storage, storage);
}

bool
database::add_activity(const char *path)
{
  item new_item;

  new_item._storage = std::make_shared<activity_storage> ();

  if (!new_item._storage->read_file(path))
    return false;

  new_item._storage->set_path(path);

  const std::string *date = new_item._storage->field_ptr("Date");
  if (date == nullptr)
    return false;

  parse_date_time(*date, &new_item._date, nullptr);

  auto it = std::lower_bound(_items.begin(), _items.end(), new_item._date,
			     [] (const item &a, time_t d) {
			       return d < a._date;
			     });

  if (it == _items.end())
    _items.push_back(new_item);
  else if (it->_date != new_item._date)
    _items.insert(it, new_item);
  else
    {
      using std::swap;
      swap(*it, new_item);
    }

  return true;
}

void
database::execute_query(const query &q, std::vector<item *> &result)
{
  result.clear();

  /* FIXME: this blows. */

  size_t to_skip = q.skip_count();
  size_t to_add = q.max_count();

  for (auto &it : _items)
    {
      // If no date ranges everything matches.

      if (q.date_ranges().size() != 0)
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
	}

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

void
database::synchronize() const
{
  for (auto &it : _items)
    it.storage()->synchronize_file();
}

void
database::complete_field_name(const char *prefix,
			      std::vector<std::string> &results) const
{
  time_t first = time(nullptr) - COMPLETION_DAYS*24*60*60;
  size_t prefix_len = strlen(prefix);

  std::set<std::string, case_insensitive_string_compare> set;

  for (const auto &it : _items)
    {
      if (it.date() < first)
	break;

      for (const auto &it2 : *it.storage())
	{
	  const std::string &field = it2.first;
	  if (strncasecmp(prefix, field.c_str(), prefix_len) == 0)
	    set.insert(field);
	}
    }

  for (const auto &it : set)
    results.push_back(it);

  case_insensitive_string_compare comp;
  std::sort(results.begin(), results.end(), comp);
}

void
database::complete_field_value(const char *field_name, const char *prefix,
			       std::vector<std::string> &results) const
{
  results.clear();

  time_t first = time(nullptr) - COMPLETION_DAYS*24*60*60;
  size_t prefix_len = strlen(prefix);

  std::set<std::string, case_insensitive_string_compare> set;

  field_id id = lookup_field_id(field_name);
  field_data_type type = lookup_field_data_type(id);

  if (type != field_data_type::string && type != field_data_type::keywords)
    return;

  for (const auto &it : _items)
    {
      if (it.date() < first)
	break;

      if (const std::string *s = it.storage()->field_ptr(field_name))
	{
	  if (type == field_data_type::string)
	    {
	      if (strncasecmp(prefix, s->c_str(), prefix_len) == 0)
		set.insert(*s);
	    }
	  else if (type == field_data_type::keywords)
	    {
	      std::vector<std::string> keys;
	      if (parse_keywords(*s, &keys))
		{
		  for (const auto &it : keys)
		    {
		      if (strncasecmp(prefix, it.c_str(), prefix_len) == 0)
			set.insert(it);
		    }
		}
	    }
	}
    }

  for (const auto &it : set)
    results.push_back(it);

  case_insensitive_string_compare comp;
  std::sort(results.begin(), results.end(), comp);
}

database::not_term::not_term(const const_query_term_ref &t)
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

database::and_term::and_term(const const_query_term_ref &l,
			     const const_query_term_ref &r)
{
  terms.push_back(l);
  terms.push_back(r);
}

void
database::and_term::add_term(const const_query_term_ref &t)
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

database::or_term::or_term(const const_query_term_ref &l,
			   const const_query_term_ref &r)
{
  terms.push_back(l);
  terms.push_back(r);
}

void
database::or_term::add_term(const const_query_term_ref &t)
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

database::equal_term::equal_term(const std::string &f,
				 const std::string &v)
: field(f),
  value(v)
{
}

bool
database::equal_term::operator()(const activity &a) const
{
  if (const std::string *str = a.storage()->field_ptr(field))
    return *str == value;
  else
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
  if (type == field_data_type::string)
    type = field_data_type::number;

  /* Use activity to read known fields, e.g. this ensures we fill in
     missing fields from any GPS file. */

  double lhs;
  if (id != field_id::custom)
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
  if (type == field_data_type::pace)
    lhs = 1/lhs, rhs = 1/rhs;

  switch (op)
    {
    case compare_op::equal:
      return lhs == rhs;
    case compare_op::not_equal:
      return lhs != rhs;
    case compare_op::greater:
      return lhs > rhs;
    case compare_op::greater_or_equal:
      return lhs >= rhs;
    case compare_op::less:
      return lhs < rhs;
    case compare_op::less_or_equal:
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
