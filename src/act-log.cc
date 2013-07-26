// -*- c-style: gnu -*-

#include "act-activity.h"
#include "act-arguments.h"
#include "act-config.h"
#include "act-database.h"
#include "act-format.h"
#include "act-util.h"

using namespace act;

namespace {

enum option_id
{
  opt_grep,
  opt_defines,
  opt_matches,
  opt_compare,
  opt_format,
  opt_max_count,
  opt_skip,
  opt_contains,
};

const arguments::option options[] =
{
  {opt_grep, "grep", 0, "REGEXP", "Add grep-body query term."},
  {opt_defines, "defines", 0, "FIELD", "Add defines-field query term."},
  {opt_matches, "matches", 0, "FIELD:REGEXP", "Add re-match query term."},
  {opt_contains, "contains", 0, "FIELD:KEYWORD", "Add keyword query term."},
  {opt_compare, "compare", 0, "FIELDxVALUE",
   "Add compare query term. 'x' from: = != < > <= >="},
  {opt_format, "format", 0, "FORMAT", "Format method."},
  {opt_format, "pretty", 0, "FORMAT", "Same as --format=FORMAT."},
  {opt_max_count, "max-count", 'n', "N", "Maximum number of activities."},
  {opt_skip, "skip", 0, "N", "First skip N activities."},
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

} // anonymous namespace

int
act_log(arguments &args, const char *format)
{
  database::query query;

  std::shared_ptr<database::and_term> query_and (new database::and_term);
  query.set_term(query_and);

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

	case opt_format:
	  format = opt_arg;
	  break;

	case opt_max_count:
	  query.set_max_count (strtol(opt_arg, nullptr, 10));
	  break;

	case opt_skip:
	  query.set_skip_count (strtol(opt_arg, nullptr, 10));
	  break;

	case arguments::opt_error:
	  fprintf(stderr, "Error: invalid argument: %s\n\n", opt_arg);
	  print_usage(args);
	  return 1;
	}
    }

  bool print_path = false, print_raw_contents = false;

  if (strcasecmp(format, "oneline") == 0)
    {
      format = "%{date:%F %-l%p}: %{distance} %{type} %{activity},"
	" %{duration}%n";
    }
  else if (strcasecmp(format, "short") == 0)
    {
      format = "%{date:%a %b %-e %-l%p}: %{distance} %{type}"
	" %{activity}, %{duration}%n%n%{body:first-para}%n";
    }
  else if (strcasecmp(format, "medium") == 0)
    {
      format = "%[Date]%[Activity]%[Type]%[Course]%[Distance]"
        "%[Duration]%n%[Body]%n";
    }
  else if (strcasecmp(format, "full") == 0)
    {
      format = "%[Header]%n%[Body]%n%[Laps]";
    }
  else if (strcasecmp(format, "raw") == 0)
    {
      print_raw_contents = true;
      format = nullptr;
    }
  else if (strcasecmp(format, "path") == 0)
    {
      print_path = true;
      format = nullptr;
    }
  else if (strncasecmp(format, "format:", strlen("format:")) == 0)
    {
      format += strlen("format:");
    }
  else
    {
      fprintf(stderr, "Error: unknown format method \"%s\".", format);
      return 1;
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

  for (const auto &it : items)
    {
      if (print_path)
	printf("%s\n", it->path().c_str());

      if (print_raw_contents)
	{
	  cat_file(it->path().c_str());
	  fputc('\n', stdout);
	}

      if (format != nullptr)
	activity(it->storage()).printf(format);
    }

  return 0;
}

int
main(int argc, const char **argv)
{
  arguments args(argc, argv);

  const char *format = "medium";

  if (args.program_name_p("act-cat"))
    {
      format = "raw";
    }
  else if (args.program_name_p("act-locate"))
    {
      format = "path";
    }
  else if (args.program_name_p("act-show"))
    {
      format = "full";
    }
  else if (args.program_name_p("act-slog"))
    {
      format = "short";
    }
  else if (args.program_name_p("act-list"))
    {
      format = "oneline";
    }

  return act_log(args, format);
}
