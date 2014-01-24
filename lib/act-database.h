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

#ifndef ACT_DATABASE_H
#define ACT_DATABASE_H

#include "act-activity.h"

#include <memory>
#include <vector>

#include <regex.h>

namespace act {

class database : public uncopyable
{
public:
  database();
  database(const database &rhs);

  void clear();

  void reload();
  void reload(const char *path);

  bool add_activity(const char *path);

  void synchronize() const;

  void complete_field_name(const char *prefix,
    std::vector<std::string> &results) const;
  void complete_field_value(const char *field_name, const char *prefix,
    std::vector<std::string> &results) const;

  class item
    {
      friend class database;

      time_t _date;
      activity_storage_ref _storage;

    public:
      item();
      item(const item &rhs) = default;

      time_t date() const {return _date;}

      activity_storage_ref storage() const {return _storage;}

      bool operator==(const item &rhs) const;
      bool operator!=(const item &rhs) const;
    };

  const std::vector<item> &items() const;

  class query_term
    {
    public:
      virtual ~query_term() {}
      virtual bool operator() (const activity &a) const = 0;
    };

  typedef std::shared_ptr<query_term> query_term_ref;
  typedef std::shared_ptr<const query_term> const_query_term_ref;

  class not_term : public query_term
    {
      const_query_term_ref term;

    public:
      explicit not_term(const const_query_term_ref &t);

      virtual bool operator() (const activity &a) const;
    };

  class and_term : public query_term
    {
      std::vector<const_query_term_ref> terms;

    public:
      and_term();
      and_term(const const_query_term_ref &l, const const_query_term_ref &r);

      void add_term(const const_query_term_ref &t);

      virtual bool operator() (const activity &a) const;
    };

  class or_term : public query_term
    {
      std::vector<const_query_term_ref> terms;

    public:
      or_term();
      or_term(const const_query_term_ref &l, const const_query_term_ref &r);

      void add_term(const const_query_term_ref &t);

      virtual bool operator() (const activity &a) const;
    };

  class equal_term : public query_term
    {
      std::string field;
      std::string value;

    public:
      equal_term(const std::string &field, const std::string &value);

      virtual bool operator() (const activity &a) const;
    };

  class matches_term : public query_term
    {
      std::string field;
      std::string regexp;
      regex_t compiled;
      int status;

    public:
      matches_term(const std::string &field, const std::string &regexp);

      virtual bool operator() (const activity &a) const;
    };

  class contains_term : public query_term
    {
      std::string field;
      std::string keyword;

    public:
      contains_term(const std::string &field, const std::string &key);

      virtual bool operator() (const activity &a) const;
    };

  class defines_term : public query_term
    {
      std::string field;

    public:
      defines_term(const std::string &field);

      virtual bool operator() (const activity &a) const;
    };

  class compare_term : public query_term
    {
    public:
      enum class compare_op
	{
	  equal,
	  not_equal,
	  greater,
	  greater_or_equal,
	  less,
	  less_or_equal
	};

    private:
      std::string field;
      compare_op op;
      double rhs;

    public:
      compare_term(const std::string &field, compare_op op, double rhs);

      virtual bool operator() (const activity &a) const;
    };

  class grep_term : public query_term
    {
      std::string regexp;
      regex_t compiled;
      int status;

    public:
      grep_term(const std::string &regexp);

      virtual bool operator() (const activity &a) const;
    };

  class query
    {
      std::vector<date_range> _dates;

      size_t _max_count;
      size_t _skip_count;

      const_query_term_ref _term;

    public:
      query() : _max_count(SIZE_T_MAX), _skip_count(0) {}

      const std::vector<date_range> date_ranges() const {return _dates;};
      void set_date_ranges(const std::vector<date_range> &vec) {_dates = vec;}
      void add_date_range(const date_range &r) {_dates.push_back(r);}

      size_t max_count() const {return _max_count;}
      void set_max_count(size_t n) {_max_count = n;}

      size_t skip_count() const {return _skip_count;}
      void set_skip_count(size_t n) {_skip_count = n;}

      void set_term(const const_query_term_ref &t) {_term = t;}
      const const_query_term_ref &term() const {return _term;}
    };

  void execute_query(const query &q, std::vector<item> &result);

private:
  std::vector<item> _items;

  static void reload_callback(const char *path, void *ctx);
};

// implementation details

inline
database::item::item()
: _date(0)
{
}

inline const std::vector<database::item> &
database::items() const
{
  return _items;
}

inline bool
database::item::operator==(const item &rhs) const
{
  return _date == rhs._date && _storage == rhs._storage;
}

inline bool
database::item::operator!=(const item &rhs) const
{
  return _date != rhs._date || _storage != rhs._storage;
}

} // namespace act

#endif /* ACT_DATABASE_H */
