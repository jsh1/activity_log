// -*- c-style: gnu -*-

#include "act-activity.h"
#include "act-activity-accum.h"
#include "act-arguments.h"
#include "act-config.h"
#include "act-database.h"
#include "act-format.h"
#include "act-output-table.h"
#include "act-util.h"

#include <map>
#include <math.h>
#include <xlocale.h>

using namespace act;

namespace {

enum option_id
{
  opt_grep,
  opt_defines,
  opt_matches,
  opt_contains,
  opt_compare,
  opt_interval,
  opt_field,
  opt_course,
  opt_keywords,
  opt_equipment,
  opt_format,
  opt_table,
  opt_table_field,
};

const arguments::option options[] =
{
  {opt_grep, "grep", 'g', "REGEXP", "Add grep-body query term."},
  {opt_defines, "defines", 'd', "FIELD", "Add defines-field query term."},
  {opt_matches, "matches", 'm', "FIELD:REGEXP", "Add re-match query term."},
  {opt_contains, "contains", 'c', "FIELD:KEYWORD", "Add keyword query term."},
  {opt_compare, "compare", 'C', "FIELDxVALUE",
   "Add compare query term. 'x' from: = != < > <= >="},
  {opt_interval, "interval", 'i', "INTERVAL", "Group by date-interval."},
  {opt_field, "field", 'f', "FIELD[:SIZE]", "Group by the named field."},
  {opt_course, "course", 0, nullptr, "Group by Course field."},
  {opt_keywords, "keywords", 'k', "FIELD", "Group by keyword."},
  {opt_equipment, "equipment", 0, nullptr, "Group by equipment."},
  {opt_format, "format", 'f', "FORMAT", "Format string."},
  {opt_table, "table", 't', "FORMAT", "Table format string."},
  {opt_table_field, "table-field", 'T', "KEY", "Field for table output."},
  {arguments::opt_eof},
};

void
print_usage(const arguments &args)
{
  fprintf(stderr, "usage: %s [OPTIONS...]\n\n", args.program_name());
  fputs("where OPTIONS are any of:\n\n", stderr);

  arguments::print_options(options, stderr);

  fputs("\n", stderr);
}

struct string_group
{
  const char *field;

  typedef std::map<std::string, activity_accum,
    case_insensitive_string_compare> group_map;

  group_map map;

  explicit string_group(const char *field);

  void insert(const activity &a);

  void format_key(std::string &buf, const std::string &key) const;
};

struct keyword_group
{
  field_id field;

  typedef std::map<std::string, activity_accum,
    case_insensitive_string_compare> group_map;

  group_map map;

  keyword_group(const char *field);

  void insert(const activity &a);

  void format_key(std::string &buf, const std::string &key) const;
};

struct value_group
{
  const char *field;
  field_id field_id;
  double bucket_size;
  double bucket_scale;

  typedef std::map<int, activity_accum> group_map;

  group_map map;

  explicit value_group(const char *field, double bucket_size);

  void insert(const activity &a);

  void format_key(std::string &buf, int key) const;
};

struct interval_group
{
  date_interval interval;

  typedef std::map<int, activity_accum> group_map;

  group_map map;

  explicit interval_group(const date_interval &interval);

  void insert(const activity &a);

  void format_key(std::string &buf, int key) const;
};

string_group::string_group(const char *f)
: field(f)
{
}

void
string_group::insert(const activity &a)
{
  if (const std::string *ptr = a.field_ptr(field))
    {
      map[*ptr].add(a);
    }
}

void
string_group::format_key(std::string &buf, const std::string &key) const
{
  buf.append(key);
}

keyword_group::keyword_group(const char *f)
: field(lookup_field_id(f))
{
}

void
keyword_group::insert(const activity &a)
{
  if (const std::vector<std::string> *ptr = a.field_keywords_ptr(field))
    {
      for (const auto &it : *ptr)
	map[it].add(a);
    }
}

void
keyword_group::format_key(std::string &buf, const std::string &key) const
{
  buf.append(key);
}

value_group::value_group(const char *f, double size)
: field(f),
  field_id(lookup_field_id(f)),
  bucket_size(size),
  bucket_scale(1 / size)
{
}

void
value_group::insert(const activity &a)
{
  double value = 0;

  if (field_id != field_id::custom)
    value = a.field_value(field_id);
  else if (const std::string *ptr = a.field_ptr(field))
    parse_number(*ptr, &value);

  if (value == 0)
    return;

  int idx = (int) floor(value * bucket_scale);

  map[idx].add(a);
}

void
value_group::format_key(std::string &buf, int key) const
{
  double min = key * bucket_size;
  double max = (key + 1) * bucket_size;

  field_data_type type = lookup_field_data_type(field_id);

  buf.push_back('[');
  format_value(buf, type, min, unit_type::unknown);
  buf.append(", ");
  format_value(buf, type, max, unit_type::unknown);
  buf.push_back(')');
}

interval_group::interval_group(const date_interval &i)
: interval(i)
{
}

void
interval_group::insert(const activity &a)
{
  time_t date = a.date();
  if (date == 0)
    return;

  int idx = interval.date_index(date);

  map[idx].add(a);
}

void
interval_group::format_key(std::string &buf, int key) const
{
  interval.append_date(buf, key);
}

template<typename T> void
output_group_format(T &g, const char *format)
{
  for (const auto &it : g.map)
    {
      std::string key;
      g.format_key(key, it.first);
      it.second.printf(format, key.c_str());
    }
}

template<typename T> void
output_group_table(T &g, const char *format)
{
  output_table tab;

  for (const auto &it : g.map)
    {
      tab.begin_row();

      std::string key;
      g.format_key(key, it.first);
      it.second.print_row(tab, format, key.c_str());

      tab.end_row();
    }

  tab.print();
}

template<typename T> void
apply_group(T &g, const std::vector<database::item *> &items,
	    const char *format, const char *table_format)
{
  for (const auto &it : items)
    g.insert(activity(it->storage()));
  
  if (format != nullptr)
    output_group_format(g, format);

  if (table_format != nullptr)
    output_group_table(g, table_format);
}

} // anonymous namespace

int
act_fold(arguments &args)
{
  database::query query;

  std::shared_ptr<database::and_term> query_and (new database::and_term);
  query.set_term(query_and);

  std::string group_field;
  bool group_keywords = false;
  double group_size = 0;
  date_interval interval(date_interval::unit_type::days, 0);

  const char *format = nullptr;
  const char *table_format = nullptr;

  while (1)
    {
      const char *opt_arg = nullptr;
      int opt = args.getopt(options, &opt_arg);
      if (opt == arguments::opt_eof)
	break;

      switch (opt)
	{
	case opt_grep: {
	  std::string re(opt_arg);
	  database::query_term_ref term (new database::grep_term(re));
	  query_and->add_term(term);
	  break; }

	case opt_defines: {
	  std::string field(opt_arg);
	  database::query_term_ref term (new database::defines_term(field));
	  query_and->add_term(term);
	  break; }

	case opt_matches:
	  if (const char *arg = strchr(opt_arg, ':'))
	    {
	      std::string field(opt_arg, arg - opt_arg);
	      std::string re(arg + 1);
	      database::query_term_ref
		term (new database::matches_term(field, re));
	      query_and->add_term(term);
	    }
	  else
	    {
	      print_usage(args);
	      return 1;
	    }
	  break;

	case opt_contains:
	  if (const char *arg = strchr(opt_arg, ':'))
	    {
	      std::string field(opt_arg, arg - opt_arg);
	      std::string key(arg + 1);
	      database::query_term_ref
		term (new database::contains_term(field, key));
	      query_and->add_term(term);
	    }
	  else
	    {
	      print_usage(args);
	      return 1;
	    }
	  break;

	case opt_compare: {
	  const char *arg = opt_arg;
	  arg += strcspn(arg, "=!<>");
	  if (*arg)
	    {
	      std::string field(opt_arg, arg - opt_arg);
	      database::compare_term::compare_op op;
	      if (arg[0] == '=')
		{
		  op = database::compare_term::compare_op::equal;
		  arg += 1;
		}
	      else if (arg[0] == '!' && arg[1] == '=')
		{
		  op = database::compare_term::compare_op::not_equal;
		  arg += 2;
		}
	      else if (arg[0] == '<' && arg[1] == '=')
		{
		  op = database::compare_term::compare_op::less_or_equal;
		  arg += 2;
		}
	      else if (arg[0] == '<')
		{
		  op = database::compare_term::compare_op::less;
		  arg += 1;
		}
	      else if (arg[0] == '>' && arg[1] == '=')
		{
		  op = database::compare_term::compare_op::greater_or_equal;
		  arg += 2;
		}
	      else if (arg[0] == '>')
		{
		  op = database::compare_term::compare_op::greater;
		  arg += 1;
		}
	      else
		{
		  print_usage(args);
		  return 1;
		}
	      field_id id = lookup_field_id(field.c_str());
	      field_data_type type = lookup_field_data_type(id);
	      if (type == field_data_type::string)
		type = field_data_type::number;
	      std::string tem(arg);
	      double rhs;
	      if (parse_value(tem, type, &rhs, nullptr))
		{
		  database::query_term_ref
		    term (new database::compare_term(field, op, rhs));
		  query_and->add_term(term);
		}
	      else
		{
		  print_usage(args);
		  return 1;
		}
	    }
	  else
	    {
	      print_usage(args);
	      return 1;
	    }
	  break; }

	case opt_interval:
	  if (!parse_date_interval(std::string(opt_arg), &interval))
	    {
	      fprintf(stderr, "Error: invalid time interval: %s\n", opt_arg);
	      return 1;
	    }
	  break;

	case opt_field:
	  if (const char *ptr = strchr(opt_arg, ':'))
	    {
	      if (group_keywords)
		{
		  fputs("Error: cannot specify both keywords and size\n",
			stderr);
		  return 1;
		}

	      group_field.clear();
	      group_field.append(opt_arg, ptr - opt_arg);

	      field_id id = lookup_field_id(group_field.c_str());
	      field_data_type type = lookup_field_data_type(id);

	      if (!parse_value(std::string(ptr+1), type, &group_size, nullptr))
		{
		  fprintf(stderr, "Error: invalid group size: %s\n", ptr+1);
		  return 1;
		}
	    }
	  else
	    group_field = opt_arg;
	  break;

	case opt_course:
	  group_field = "course";
	  break;

	case opt_keywords:
	  if (group_size != 0)
	    {
	      fputs("Error: cannot specify both keywords and size\n", stderr);
	      return 1;
	    }
	  group_field = opt_arg;
	  group_keywords = true;
	  break;

	case opt_equipment:
	  group_field = "equipment";
	  group_keywords = true;
	  break;

	case opt_format:
	  format = opt_arg;
	  break;

	case opt_table:
	  table_format = opt_arg;
	  break;

	case opt_table_field: {
	  char *fmt = nullptr;
	  asprintf(&fmt, "%%-{key} %%{%s} %%@{%s}", opt_arg, opt_arg);
	  table_format = fmt;
	  break; }

	case arguments::opt_error:
	  fprintf(stderr, "Error: invalid argument: %s\n\n", opt_arg);
	  print_usage(args);
	  return 1;
	}
    }

  if (format == nullptr && table_format == nullptr)
    table_format = "%-{key} %{distance} %@{distance}";

  if (args.argc() != 0)
    {
      std::vector<date_range> dates;

      if (!args.make_date_range(dates))
	return 1;

      query.set_date_ranges(dates);
    }
  else
    query.add_date_range(date_range::infinity());

  database db;

  std::vector<database::item *> items;
  db.execute_query(query, items);

  if (group_field.size() != 0)
    {
      if (group_keywords)
	{
	  keyword_group g(group_field.c_str());
	  apply_group(g, items, format, table_format);
	}
      else if (group_size > 0)
	{
	  value_group g(group_field.c_str(), group_size);
	  apply_group(g, items, format, table_format);
	}
      else
	{
	  string_group g(group_field.c_str());
	  apply_group(g, items, format, table_format);
	}
    }
  else if (interval.count > 0)
    {
      interval_group g(interval);
      apply_group(g, items, format, table_format);
    }

  return 0;
}

int
main(int argc, const char **argv)
{
  arguments args(argc, argv);

  const char *interval = nullptr;

  if (args.program_name_p("act-daily"))
    {
      interval = "day";
    }
  else if (args.program_name_p("act-weekly"))
    {
      interval = "week";
    }
  else if (args.program_name_p("act-monthly"))
    {
      interval = "month";
    }
  else if (args.program_name_p("act-yearly"))
    {
      interval = "year";
    }

  if (interval != nullptr)
    {
      args.push_front(interval);
      args.push_front("--interval");
    }

  return act_fold(args);
}
