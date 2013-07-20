// -*- c-style: gnu -*-

#include "act-activity.h"
#include "act-arguments.h"
#include "act-config.h"
#include "act-database.h"

using namespace act;

namespace {

enum option_id
{
  opt_format,
  opt_max_count,
  opt_skip,
};

const arguments::option options[] =
{
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
  size_t max_count = SIZE_T_MAX;
  size_t skip_count = 0;

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
	  max_count = strtol(opt_arg, nullptr, 10);
	  break;

	case opt_skip:
	  skip_count = strtol(opt_arg, nullptr, 10);
	  break;

	case arguments::opt_error:
	  fprintf(stderr, "Error: invalid argument: %s\n\n", opt_arg);
	  print_usage(args);
	  return 1;
	}
    }

  if (strcasecmp(format, "oneline") == 0)
    {
      format = "%{date:%F %-l%p}: %{distance} %{type}, %{duration} %{pace}%n";
    }
  else if (strcasecmp(format, "short") == 0)
    {
      format = "%{date:%a %b %-e %-l%p}: %{distance} %{type}"
	" %{activity}, %{duration} %{pace}%n%n%{body:first-para}%n";
    }
  else if (strcasecmp(format, "medium") == 0)
    {
      format = "%[Date]%[Activity]%[Type]%[Distance]"
        "%[Duration]%n%{body}%n";
    }
  else if (strcasecmp(format, "full") == 0)
    {
      format = "%{all-fields}%n%{body}%n";
    }
  else if (strcasecmp(format, "raw") == 0)
    {
      format = "%{activity-data}";
    }
  else if (strcasecmp(format, "path") == 0)
    {
      format = "%{activity-path}%n";
    }
  else if (strncasecmp(format, "format:", strlen("format:")) == 0)
    {
      format += strlen("format:");
    }
  else
    {
      fprintf(stderr, "Error: unknown format method \"%s\".", format);
      exit(1);
    }

  std::vector<date_range> dates;

  if (args.argc() != 0)
    {
      if (!args.make_date_range(dates))
	return 1;
    }
  else
    dates.push_back(date_range(0, time(nullptr)));

  database db;

  std::vector<database::activity_ref> activities;
  db.enumerate_activities(activities, dates, skip_count, max_count);

  for (const auto &a : activities)
    {
      a->printf(stdout, format);
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
      format = "full";
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
