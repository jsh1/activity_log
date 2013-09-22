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

  void reload();
  void synchronize() const;

  class item
    {
      friend class database;

      time_t _date;
      activity_storage_ref _storage;

    public:
      time_t date() const {return _date;}

      activity_storage_ref storage() {return _storage;}
      const_activity_storage_ref storage() const {
	return std::const_pointer_cast<const activity_storage> (_storage);}
    };

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

  void execute_query(const query &q, std::vector<item *> &result);

private:
  std::vector<item> _items;

  static void reload_callback(const char *path, void *ctx);
};

} // namespace act

#endif /* ACT_DATABASE_H */
