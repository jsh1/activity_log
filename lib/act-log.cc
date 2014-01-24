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
  {opt_grep, "grep", 'g', "REGEXP", "Add grep-body query term."},
  {opt_defines, "defines", 'd', "FIELD", "Add defines-field query term."},
  {opt_matches, "matches", 'm', "FIELD:REGEXP", "Add re-match query term."},
  {opt_contains, "contains", 'c', "FIELD:KEYWORD", "Add keyword query term."},
  {opt_compare, "compare", 'C', "FIELDxVALUE",
   "Add compare query term. 'x' from: = != < > <= >="},
  {opt_format, "format", 'f', "FORMAT", "Format method."},
  {opt_format, "pretty", 'p', "FORMAT", "Same as --format=FORMAT."},
  {opt_max_count, "max-count", 'n', "N", "Maximum number of activities."},
  {opt_skip, "skip", 's', "N", "First skip N activities."},
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
	  database::query_term_ref term (new database::grep_term(re));
	  query_and->add_term(term);
	  break; }

	case opt_defines: {
	  std::string field(opt_arg);
	  database::query_term_ref term (new database::defines_term(field));
	  query_and->add_term(term);
	  break; }

	case opt_matches: {
	  const char *arg = strchr(opt_arg, ':');
	  if (arg)
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
	  break; }

	case opt_contains: {
	  const char *arg = strchr(opt_arg, ':');
	  if (arg)
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
	  break; }

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
      format = "%{date:%F %-l%p}: %{activity} %{distance} %{type},"
	" %{duration}%n";
    }
  else if (strcasecmp(format, "short") == 0)
    {
      format = "%{date:%a %b %-e %-l%p}: %{activity} %{distance} %{type},"
	" %{duration}%n%n%{body:first-para}%n";
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
    query.add_date_range(date_range::infinity());

  database db;
  db.reload();

  std::vector<database::item> items;
  db.execute_query(query, items);

  for (const auto &it : items)
    {
      if (print_path)
	printf("%s\n", it.storage()->path());

      if (print_raw_contents)
	{
	  cat_file(it.storage()->path());
	  fputc('\n', stdout);
	}

      if (format != nullptr)
	activity(it.storage()).printf(format);
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
