// -*- c-style: gnu -*-

#include "act-activity.h"
#include "act-arguments.h"
#include "act-config.h"
#include "act-database.h"
#include "act-util.h"

using namespace act;

namespace {

enum option_id
{
  opt_format,
  opt_max_count,
  opt_skip,
  opt_grep,
};

const arguments::option options[] =
{
  {opt_format, "format", 0, "FORMAT", "Format method."},
  {opt_format, "pretty", 0, "FORMAT", "Same as --format=FORMAT."},
  {opt_max_count, "max-count", 'n', "N", "Maximum number of activities."},
  {opt_skip, "skip", 0, "N", "First skip N activities."},
  {opt_grep, "grep", 0, "FIELD:REGEXP", "Add grep query term."},
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
	case opt_format:
	  format = opt_arg;
	  break;

	case opt_max_count:
	  query.set_max_count (strtol(opt_arg, nullptr, 10));
	  break;

	case opt_skip:
	  query.set_skip_count (strtol(opt_arg, nullptr, 10));
	  break;

	case opt_grep: {
	  const char *arg = strchr(opt_arg, ':');
	  if (!arg)
	    arg = opt_arg + strlen(opt_arg);
	  std::string field(opt_arg, arg - opt_arg);
	  std::string re(arg + 1);
	  std::shared_ptr<database::query_term>
	    grep (new database::grep_term(field, re));
	  query_and->add_term(grep);
	  break; }

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
