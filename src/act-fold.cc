// -*- c-style: gnu -*-

#include "act-activity.h"
#include "act-arguments.h"
#include "act-config.h"
#include "act-database.h"
#include "act-format.h"
#include "act-util.h"

#include <unordered_map>
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
  opt_size,
  opt_format,
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
  {opt_field, "field", 'f', "FIELD", "Group by the named field."},
  {opt_course, "course", 0, nullptr, "Group by Course field."},
  {opt_keywords, "keywords", 'k', "FIELD", "Group by keyword."},
  {opt_equipment, "equipment", 0, nullptr, "Group by equipment."},
  {opt_size, "size", 's', "SIZE", "Group by numeric field value."},
  {opt_format, "format", 'f', "FORMAT", "Format method."},
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

struct activity_sum
{
  int _count;
  double _distance;
  int _distance_samples;
  double _duration;
  int _duration_samples;
  double _average_hr;
  int _average_hr_samples;
  double _max_hr;
  double _resting_hr;
  int _resting_hr_samples;
  double _calories;
  double _weight;
  int _weight_samples;
  double _effort;
  int _effort_samples;
  double _quality;
  int _quality_samples;
  double _temperature;
  int _temperature_samples;
  double _dew_point;
  int _dew_point_samples;

  activity_sum();

  void add(const activity &a);
  void print(const std::string &key) const;
};

struct string_group
{
  const char *field;

  typedef std::unordered_map<std::string, activity_sum,
    case_insensitive_string_hash, case_insensitive_string_pred> group_map;

  group_map map;

  explicit string_group(const char *field);

  void insert(const activity &a);

  void format_key(std::string &buf, const std::string &key) const;
};

struct keyword_group
{
  field_id field;

  typedef std::unordered_map<std::string, activity_sum,
    case_insensitive_string_hash, case_insensitive_string_pred> group_map;

  group_map map;

  keyword_group(const char *field);

  void insert(const activity &a);

  void format_key(std::string &buf, const std::string &key) const;
};

struct value_group
{
  field_id field;
  double bucket_size;
  double bucket_scale;

  typedef std::unordered_map<int, activity_sum> group_map;

  group_map map;

  explicit value_group(const char *field, double bucket_size);

  void insert(const activity &a);

  void format_key(std::string &buf, int key) const;
};

struct interval_group
{
  date_interval interval;

  typedef std::unordered_map<int, activity_sum> group_map;

  group_map map;

  explicit interval_group(const date_interval &interval);

  void insert(const activity &a);

  void format_key(std::string &buf, int key) const;
};

activity_sum::activity_sum()
: _count(0),
  _distance(0),
  _distance_samples(0),
  _duration(0),
  _duration_samples(0),
  _average_hr(0),
  _average_hr_samples(0),
  _max_hr(0),
  _resting_hr(0),
  _resting_hr_samples(0),
  _calories(0),
  _weight(0),
  _weight_samples(0),
  _effort(0),
  _effort_samples(0),
  _quality(0),
  _quality_samples(0),
  _temperature(0),
  _temperature_samples(0),
  _dew_point(0),
  _dew_point_samples(0)
{
}

void
activity_sum::add(const activity &a)
{
  _count++;

  if (a.distance() != 0)
    _distance += a.distance(), _distance_samples++;

  if (a.duration() != 0)
    _duration += a.duration(), _duration_samples++;

  if (a.average_hr() != 0)
    _average_hr += a.average_hr(), _average_hr_samples++;

  _max_hr = std::max(_max_hr, a.max_hr());

  if (a.resting_hr() != 0)
    _resting_hr += a.resting_hr(), _resting_hr_samples++;

  _calories += a.calories();

  if (a.weight() != 0)
    _weight += a.weight(), _weight_samples++;

  if (a.effort() != 0)
    _effort += a.effort(), _effort_samples++;

  if (a.quality() != 0)
    _quality += a.quality(), _quality_samples++;

  if (a.temperature() != 0)
    _temperature += a.temperature(), _temperature_samples++;

  if (a.dew_point() != 0)
    _dew_point += a.dew_point(), _dew_point_samples++;
}

void
activity_sum::print(const std::string &key) const
{
  std::string dist;
  format_distance(dist, _distance, shared_config().default_distance_unit());

  std::string dur;
  format_time(dur, _duration, true, "");

  std::string avg_hr, max_hr, rest_hr;
  if (_average_hr != 0)
    format_number(avg_hr, _average_hr / (double)_average_hr_samples);
  if (_max_hr != 0)
    format_number(max_hr, _max_hr);
  if (_resting_hr != 0)
    format_number(rest_hr, _resting_hr / (double)_resting_hr_samples);

  std::string weight;
  if (_weight != 0)
    format_weight(weight, _weight, shared_config().default_weight_unit());

  std::string temp, dew;
  if (_temperature != 0)
    format_temperature(temp, _temperature / (double)_temperature_samples, shared_config().default_temperature_unit());
  if (_dew_point != 0)
    format_temperature(dew, _dew_point / (double)_dew_point_samples, shared_config().default_temperature_unit());

  std::string effort, quality;
  if (_effort != 0)
    format_fraction(effort, _effort / (double)_effort_samples);
  if (_quality != 0)
    format_fraction(quality, _quality / (double)_quality_samples);

  printf("%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", key.c_str(),
	 _count, dist.c_str(), dur.c_str(), avg_hr.c_str(), max_hr.c_str(),
	 rest_hr.c_str(), weight.c_str(), temp.c_str(), dew.c_str(),
	 effort.c_str(), quality.c_str());
}

string_group::string_group(const char *f)
: field(f)
{
}

void
string_group::insert(const activity &a)
{
  if(const std::string *ptr = a.field_ptr(field))
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
  if(const std::vector<std::string> *ptr = a.field_keywords_ptr(field))
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
: field(lookup_field_id(f)),
  bucket_size(size),
  bucket_scale(1 / size)
{
}

void
value_group::insert(const activity &a)
{
  double value = a.field_value(field);
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

  field_data_type type = lookup_field_data_type(field);

  buf.push_back('[');
  format_value(buf, type, min, unit_unknown);
  buf.append(", ");
  format_value(buf, type, max, unit_unknown);
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

  // FIXME: how is this going to work? Need to include date as well?

//  int idx = interval.date_index(date);
  int idx = 0;

  map[idx].add(a);
}

void
interval_group::format_key(std::string &buf, int key) const
{
  // FIXME: implement this

  char tem[512];
  snprintf_l(tem, sizeof(tem), nullptr, "[%d %s @ %d]",
	     interval.count, interval.unit == date_interval::days ? "days"
	     : interval.unit == date_interval::weeks ? "weeks"
	     : interval.unit == date_interval::months ? "months"
	     : interval.unit == date_interval::years ? "years"
	     : "unknown", key);

  buf.append(tem);
}

template<typename T> void
apply_group(T &g, const std::vector<database::item_ref> &items)
{
  for (const auto &it : items)
    g.insert(activity(it->storage()));

  // FIXME: ignoring format string

  for (const auto &it : g.map)
    {
      std::string key;
      g.format_key(key, it.first);
      it.second.print(key);
    }
}

} // anonymous namespace

int
act_fold(arguments &args)
{
  database::query query;

  std::shared_ptr<database::and_term> query_and (new database::and_term);
  query.set_term(query_and);

  const char *group_field = nullptr;
  bool group_keywords = false;
  double bucket_size = 0;
  date_interval interval(date_interval::days, 0);
  const char *format = nullptr;

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
	  std::shared_ptr<database::query_term>
	    term (new database::grep_term(re));
	  query_and->add_term(term);
	  break; }

	case opt_defines: {
	  std::string field(opt_arg);
	  std::shared_ptr<database::query_term>
	    term (new database::defines_term(field));
	  query_and->add_term(term);
	  break; }

	case opt_matches: {
	  const char *arg = strchr(opt_arg, ':');
	  if (arg)
	    {
	      std::string field(opt_arg, arg - opt_arg);
	      std::string re(arg + 1);
	      std::shared_ptr<database::query_term>
		term (new database::matches_term(field, re));
	      query_and->add_term(term);
	    }
	  else
	    {
	      print_usage(args);
	      return 1;
	    }
	  break; }

	case opt_contains: {
	  const char *arg = strchr(opt_arg, ':');
	  if (arg)
	    {
	      std::string field(opt_arg, arg - opt_arg);
	      std::string key(arg + 1);
	      std::shared_ptr<database::query_term>
		term (new database::contains_term(field, key));
	      query_and->add_term(term);
	    }
	  else
	    {
	      print_usage(args);
	      return 1;
	    }
	  break; }

	case opt_compare: {
	  const char *arg = opt_arg;
	  arg += strcspn(arg, "=!<>");
	  if (*arg)
	    {
	      std::string field(opt_arg, arg - opt_arg);
	      database::compare_term::compare_op op;
	      if (arg[0] == '=')
		op = database::compare_term::op_equal, arg += 1;
	      else if (arg[0] == '!' && arg[1] == '=')
		op = database::compare_term::op_not_equal, arg += 2;
	      else if (arg[0] == '<' && arg[1] == '=')
		op = database::compare_term::op_less_or_equal, arg += 2;
	      else if (arg[0] == '<')
		op = database::compare_term::op_less, arg += 1;
	      else if (arg[0] == '>' && arg[1] == '=')
		op = database::compare_term::op_greater_or_equal, arg += 2;
	      else if (arg[0] == '>')
		op = database::compare_term::op_greater, arg += 1;
	      else
		{
		  print_usage(args);
		  return 1;
		}
	      field_id id = lookup_field_id(field.c_str());
	      field_data_type type = lookup_field_data_type(id);
	      if (type == type_string)
		type = type_number;
	      std::string tem(arg);
	      double rhs;
	      if (parse_value(tem, type, &rhs, nullptr))
		{
		  std::shared_ptr<database::query_term>
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
	  group_field = opt_arg;
	  break;

	case opt_course:
	  group_field = "course";
	  break;

	case opt_keywords:
	  group_field = opt_arg;
	  group_keywords = true;
	  break;

	case opt_equipment:
	  group_field = "equipment";
	  group_keywords = true;
	  break;

	case opt_size:
	  if (group_field)
	    {
	      field_id id = lookup_field_id(group_field);
	      field_data_type type = lookup_field_data_type(id);
	      if (parse_value(std::string(opt_arg), type, &bucket_size, nullptr))
		break;
	    }
	  bucket_size = strtod(opt_arg, nullptr);
	  break;

	case opt_format:
	  format = opt_arg;
	  break;

	case arguments::opt_error:
	  fprintf(stderr, "Error: invalid argument: %s\n\n", opt_arg);
	  print_usage(args);
	  return 1;
	}
    }

  if (args.argc() != 0)
    {
      std::vector<date_range> dates;

      if (!args.make_date_range(dates))
	return 1;

      query.set_date_ranges(dates);
    }
  else
    query.add_date_range(date_range(0, time(nullptr)));

  database db;

  std::vector<database::item_ref> items;
  db.execute_query(query, items);

  if (group_field)
    {
      if (group_keywords)
	{
	  keyword_group g(group_field);
	  apply_group(g, items);
	}
      else if (bucket_size > 0)
	{
	  value_group g(group_field, bucket_size);
	  apply_group(g, items);
	}
      else
	{
	  string_group g(group_field);
	  apply_group(g, items);
	}
    }
  else if (interval.count > 0)
    {
      interval_group g(interval);
      apply_group(g, items);
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
