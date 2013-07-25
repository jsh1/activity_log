// -*- c-style: gnu -*-

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

  typedef item *item_ref;

  class query_term
    {
    public:
      virtual ~query_term() {}
      virtual bool operator() (const item &it) const = 0;
    };

  class not_term : public query_term
    {
      std::shared_ptr<const query_term> term;

    public:
      explicit not_term(const std::shared_ptr<const query_term> &t);

      virtual bool operator() (const item &it) const;
    };

  class and_term : public query_term
    {
      std::vector<std::shared_ptr<const query_term>> terms;

    public:
      and_term();
      and_term(const std::shared_ptr<const query_term> &l,
	       const std::shared_ptr<const query_term> &r);

      void add_term(const std::shared_ptr<const query_term> &t);

      virtual bool operator() (const item &it) const;
    };

  class or_term : public query_term
    {
      std::vector<std::shared_ptr<const query_term>> terms;

    public:
      or_term();
      or_term(const std::shared_ptr<const query_term> &l,
	      const std::shared_ptr<const query_term> &r);

      void add_term(const std::shared_ptr<const query_term> &t);

      virtual bool operator() (const item &it) const;
    };

  class grep_term : public query_term
    {
      std::string field;
      std::string regexp;
      regex_t compiled;
      int status;

    public:
      grep_term(const std::string &f, const std::string &re);

      virtual bool operator() (const item &it) const;
    };

  class query
    {
      std::vector<date_range> _dates;

      size_t _max_count;
      size_t _skip_count;

      std::shared_ptr<const query_term> _term;

    public:
      query() : _max_count(SIZE_T_MAX), _skip_count(0) {}

      const std::vector<date_range> date_ranges() const {return _dates;};
      void set_date_ranges(const std::vector<date_range> &vec) {_dates = vec;}
      void add_date_range(const date_range &r) {_dates.push_back(r);}

      size_t max_count() const {return _max_count;}
      void set_max_count(size_t n) {_max_count = n;}

      size_t skip_count() const {return _skip_count;}
      void set_skip_count(size_t n) {_skip_count = n;}

      void set_term(const std::shared_ptr<const query_term> &t) {_term = t;}
      const std::shared_ptr<const query_term> &term() const {return _term;}
    };

  void execute_query(const query &q, std::vector<item_ref> &result);

private:
  std::vector<item> _items;

  void read_activities();

  static void read_activities_callback(const char *path, void *ctx);
};

} // namespace act

#endif /* ACT_DATABASE_H */
