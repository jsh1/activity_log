// -*- c-style: gnu -*-

#include "act-activity.h"
#include "act-arguments.h"
#include "act-config.h"
#include "act-gps-activity.h"
#include "act-util.h"

using namespace act;

namespace {

enum option_id
{
  // new options
  opt_edit,
  opt_date,
  opt_activity,
  opt_type,
  opt_course,
  opt_keyword,
  opt_equipment,
  opt_distance,
  opt_duration,
  opt_pace,
  opt_speed,
  opt_max_pace,
  opt_max_speed,
  opt_resting_hr,
  opt_average_hr,
  opt_max_hr,
  opt_calories,
  opt_weight,
  opt_temperature,
  opt_weather,
  opt_quality,
  opt_effort,
  opt_gps_file,
  opt_field,
  // import options
  opt_import_all,
};

activity::field_id
option_field_id(option_id opt)
{
  switch (opt)
    {
    case opt_date:
      return activity::field_date;
    case opt_activity:
      return activity::field_activity;
    case opt_type:
      return activity::field_type;
    case opt_course:
      return activity::field_course;
    case opt_keyword:
      return activity::field_keywords;
    case opt_equipment:
      return activity::field_equipment;
    case opt_distance:
      return activity::field_distance;
    case opt_duration:
      return activity::field_duration;
    case opt_pace:
      return activity::field_pace;
    case opt_speed:
      return activity::field_speed;
    case opt_max_pace:
      return activity::field_max_pace;
    case opt_max_speed:
      return activity::field_max_speed;
    case opt_resting_hr:
      return activity::field_resting_hr;
    case opt_average_hr:
      return activity::field_average_hr;
    case opt_max_hr:
      return activity::field_max_hr;
    case opt_calories:
      return activity::field_calories;
    case opt_weight:
      return activity::field_weight;
    case opt_temperature:
      return activity::field_temperature;
    case opt_weather:
      return activity::field_weather;
    case opt_quality:
      return activity::field_quality;
    case opt_effort:
      return activity::field_effort;
    case opt_gps_file:
      return activity::field_gps_file;
    case opt_field:
      return activity::field_custom;
    case opt_edit:
    case opt_import_all:
      abort();
    }
}

const arguments::option new_options[] =
{
  {opt_edit, "edit", 0, 0, "Open new file in editor."},
  {opt_date, "date", 0, "DATE", 0},
  {opt_activity, "activity", 0, "ACTIVITY-SPEC"},
  {opt_type, "type", 0, "ACTIVITY-TYPE"},
  {opt_course, "course", 0, "COURSE-NAME"},
  {opt_keyword, "keyword", 0, "KEYWORD"},
  {opt_equipment, "equipment", 0, "EQUIPMENT"},
  {opt_distance, "distance", 0, "DISTANCE"},
  {opt_duration, "duration", 0, "DURATION"},
  {opt_pace, "pace", 0, "PACE"},
  {opt_speed, "speed", 0, "SPEED"},
  {opt_max_pace, "max-pace", 0, "MAX-PACE"},
  {opt_max_speed, "max-speed", 0, "MAX-SPEED"},
  {opt_resting_hr, "resting-hr", 0, "RESTING-HR"},
  {opt_average_hr, "average-hr", 0, "AVG-HR"},
  {opt_max_hr, "max-hr", 0, "MAX-HR"},
  {opt_calories, "calories", 0, "CALORIES"},
  {opt_weight, "weight", 0, "WEIGHT"},
  {opt_temperature, "temperature", 0, "TEMP"},
  {opt_weather, "weather", 0, "WEATHER"},
  {opt_quality, "quality", 0, "QUALITY-RATIO"},
  {opt_effort, "effort", 0, "EFFORT-RATIO"},
  {opt_gps_file, "gps-file", 0, "GPS-FILE"},
  {opt_field, "field", 0, "NAME:VALUE", "Define custom field."},
  {arguments::opt_eof}
};

const arguments::option import_options[] =
{
  {opt_import_all, "import-all", 0, 0, "Import all new GPS files."},
  {arguments::opt_eof}
};

void
print_usage(const arguments &args, bool for_import)
{
  fprintf(stderr, "usage: %s [OPTIONS...]\n\n", args.program_name());
  fputs("where OPTIONS are any of:\n\n", stderr);

  if (for_import)
    arguments::print_options(import_options, stderr);

  arguments::print_options(new_options, stderr);

  fputs("\n", stderr);
}

void
copy_gps_fields(activity &a, const gps::activity &gps_data)
{
  if (!a.has_field(activity::field_date))
    a.set_date((time_t) gps_data.time());

  if (gps_data.sport() != gps::activity::sport_unknown
      && !a.has_field(activity::field_activity))
    {
      gps::activity::sport_type sport = gps_data.sport();
      std::string type;
      if (sport == gps::activity::sport_running)
	type = "run";
      else if (sport == gps::activity::sport_cycling)
	type = "bike";
      if (sport == gps::activity::sport_swimming)
	type = "swim";
      if (type.size() != 0)
	a.set_string_field(activity::field_activity, type);
    }

  if (gps_data.duration() > 0
      && !a.has_field(activity::field_duration))
    a.set_duration_field(activity::field_duration, gps_data.duration());

  if (gps_data.distance() > 0
      && !a.has_field(activity::field_distance))
    a.set_distance_field(activity::field_distance, gps_data.distance());

#if 0
  /* FIXME: Decide whether or not to copy these fields. They seem
     gratuitous. Also, set [max-]pace if running, speed if biking. */

  if (gps_data.avg_speed() > 0
      && !a.has_field(activity::field_pace)
      && !a.has_field(activity::field_speed))
    a.set_pace_field(activity::field_pace, gps_data.avg_speed());

  if (gps_data.max_speed() > 0
      && !a.has_field(activity::field_max_pace)
      && !a.has_field(activity::field_max_speed))
    a.set_pace_field(activity::field_max_pace, gps_data.max_speed());
#endif

  if (gps_data.avg_heart_rate() > 0
      && !a.has_field(activity::field_average_hr))
    a.set_numeric_field(activity::field_average_hr, gps_data.avg_heart_rate());

  if (gps_data.max_heart_rate() > 0
      && !a.has_field(activity::field_max_hr))
    a.set_numeric_field(activity::field_max_hr, gps_data.max_heart_rate());

  // FIXME: do something with lap data?
}

} // anonymous namespace

int
act_new(arguments &args)
{
  bool edit = false;
  activity a;

  while (1)
    {
      const char *opt_arg = 0;
      int opt = args.getopt(new_options, &opt_arg);
      if (opt == arguments::opt_eof)
	break;

      switch (opt)
	{
	case opt_edit:
	  edit = true;
	  break;

	case opt_date: {
	  time_t date;
	  if (parse_date_time(std::string(opt_arg), &date, 0))
	    a.set_date(date);
	  break; }

	  // keyword arguments concatenate into existing values

	case opt_keyword:
	case opt_equipment:
	case opt_weather: {
	  activity::field_id field = option_field_id((option_id)opt);
	  std::vector<std::string> keys;
	  a.get_keywords_field(field, &keys);
	  keys.push_back(std::string(opt_arg));
	  a.set_keywords_field(field, keys);
	  break; }

	  // GPS files have directories stripped

	case opt_field: {
	  std::string arg(opt_arg);
	  std::string name, value;
	  size_t idx = arg.find_first_of(':');
	  if (idx != std::string::npos)
	    {
	      name = arg.substr(0, idx);
	      value = arg.substr(idx, arg.size() - (idx + 1));
	    }
	  else
	    std::swap(name, arg);
	  std::swap(a.field_value(activity::field_name(name)), value);
	  break; }

	case opt_gps_file:
	  if (const char *tem = strrchr(opt_arg, '/'))
	    opt_arg = tem + 1;
	  /* fall through */

	default: {
	  activity::field_id field = option_field_id((option_id)opt);
	  std::string str(opt_arg);
	  a.canonicalize_field_string(field, str);
	  std::swap(a.field_value(field), str);
	  break; }

	case arguments::opt_error:
	  fprintf(stderr, "Error: invalid argument: %s\n\n", opt_arg);
	  print_usage(args, false);
	  return 1;
	}
    }

  if (a.has_field(activity::field_gps_file))
    {
      const std::string *s;
      a.get_string_field(activity::field_name(activity::field_gps_file), &s);

      std::string filename(*s);
      if (shared_config().find_gps_file(filename))
	{
	  gps::activity gps_data;
	  if (gps_data.read_file(filename.c_str()))
	    copy_gps_fields(a, gps_data);
	}
    }

  std::string filename;
  if (!a.make_filename(filename))
    return 1;

  if (!a.write_file(filename.c_str()))
    return 1;

  fprintf(stderr, "Created %s\n", filename.c_str());

  if (edit)
    shared_config().edit_file(filename.c_str());

  return 0;
}

int
act_import(arguments &args)
{
  bool import_all = false;

  while (1)
    {
      const char *opt_arg = 0;
      int opt = args.getopt(import_options, &opt_arg, arguments::opt_partial);
      if (opt == arguments::opt_eof)
	break;

      switch (opt)
	{
	case opt_import_all:
	  import_all = true;
	  break;

	case arguments::opt_error:
	  fprintf(stderr, "Error: invalid argument: %s\n\n", opt_arg);
	  print_usage(args, true);
	  return 1;
	}
    }

  std::vector<std::string> new_files;
  shared_config().find_new_gps_files(new_files);

  if (new_files.size() == 0)
    {
      if (!shared_config().silent())
	fprintf(stderr, "No new GPS activities.\n");

      return 0;
    }

  for (const auto &it : new_files)
    {
      bool should_import = false;

      if (import_all)
	should_import = true;
      else
	{
	  fprintf(stderr, "Import %s? (y/n) [y] ", it.c_str());
	  fflush(stderr);

	  char buf[64];
	  if (!fgets(buf, sizeof(buf), stdin))
	    return 0;

	  if (buf[0] == '\n' || (buf[0] == 'y' && buf[1] == '\n'))
	    should_import = true;
	}

      if (should_import)
	{
	  arguments copy(args);
	  copy.push_back("--gps-file");
	  copy.push_back(it);

	  int ret = act_new(copy);
	  if (ret != 0)
	    return ret;
	}
    }

  return 0;
}

int
main(int argc, const char **argv)
{
  arguments args(argc, argv);

  if (args.program_name_p("act-import"))
    return act_import(args);
  else
    return act_new(args);
}
