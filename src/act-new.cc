// -*- c-style: gnu -*-

#include "act-activity.h"
#include "act-arguments.h"
#include "act-config.h"
#include "act-gps-activity.h"
#include "act-gps-parser.h"
#include "act-gps-fit-parser.h"
#include "act-gps-tcx-parser.h"

using namespace act;

enum option_id
{
  opt_edit = 1,
  opt_date,
  opt_activity,
  opt_type,
  opt_course,
  opt_keywords,
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
  opt_fit_file,
  opt_tcx_file,
  opt_field,
};

namespace {

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
    case opt_keywords:
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
    case opt_fit_file:
      return activity::field_fit_file;
    case opt_tcx_file:
      return activity::field_tcx_file;
    case opt_field:
      return activity::field_custom;
    case opt_edit:
      abort();
    }
}

const arguments::option options[] =
{
  {opt_edit, "edit", 0, false},
  {opt_date, "date", true, 0},
  {opt_activity, "activity", 0, true},
  {opt_type, "type", 0, true},
  {opt_course, "course", 0, true},
  {opt_keywords, "keywords", 0, true},
  {opt_equipment, "equipment", 0, true},
  {opt_distance, "distance", 0, true},
  {opt_duration, "duration", 0, true},
  {opt_pace, "pace", 0, true},
  {opt_speed, "speed", 0, true},
  {opt_max_pace, "max-pace", 0, true},
  {opt_max_speed, "max-speed", 0, true},
  {opt_resting_hr, "resting-hr", 0, true},
  {opt_average_hr, "average-hr", 0, true},
  {opt_max_hr, "max-hr", 0, true},
  {opt_calories, "calories", 0, true},
  {opt_weight, "weight", 0, true},
  {opt_temperature, "temperature", 0, true},
  {opt_weather, "weather", 0, true},
  {opt_quality, "quality", 0, true},
  {opt_effort, "effort", 0, true},
  {opt_fit_file, "fit-file", 0, true},
  {opt_tcx_file, "tcx-file", 0, true},
  {opt_field, "field", 0, true},
  {EOF}
};

bool
string_has_suffix(const std::string &str, const char *suffix)
{
  size_t len = strlen(suffix);
  if (str.size() < len)
    return false;

  return str.compare(str.size() - len, std::string::npos, suffix) == 0;
}

void
import_gps_fields(activity &a, const gps::activity &gps_data)
{
  // FIXME: implement this.
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
      int opt = args.getopt(options, &opt_arg);
      if (opt == arguments::opt_eof)
	break;

      switch (opt)
	{
	case opt_edit:
	  edit = true;
	  break;

	case opt_date: {
	  time_t date;
	  parse_date(std::string(opt_arg), &date, 0);
	  a.set_date(date);
	  break; }

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

	  // keyword arguments concatenate into existing values

	case opt_keywords:
	case opt_equipment:
	case opt_weather: {
	  activity::field_id field = option_field_id((option_id)opt);
	  std::string &value = a.field_value(activity::field_name(field));
	  value.push_back(' ');
	  value.append(opt_arg);
	  break; }

	default: {
	  activity::field_id field = option_field_id((option_id)opt);
	  a.field_value(activity::field_name(field)) = *opt_arg;
	  break; }

	case arguments::opt_error:
	  fprintf(stderr, "Error: invalid argument: %s\n", opt_arg);
	  return 1;
	  break;
	}
    }

  bool has_fit_file = a.has_field(activity::field_fit_file);
  bool has_tcx_file = a.has_field(activity::field_tcx_file);

  if (has_fit_file || has_tcx_file)
    {
      const std::string *s;
      a.get_string_field(activity::field_name(has_fit_file
					      ? activity::field_fit_file
					      : activity::field_tcx_file),
			 &s);

      std::string filename(*s);
      if (shared_config().find_gps_file(filename))
	{
	  gps::activity gps_data;

	  if (has_fit_file)
	    gps_data.read_fit_file(filename.c_str());
	  else
	    gps_data.read_tcx_file(filename.c_str());

	  import_gps_fields(a, gps_data);
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
main(int argc, const char **argv)
{
  arguments args(argc, argv);

  if (args.program_name_p("act-import"))
    {
      std::vector<std::string> new_files;
      shared_config().find_new_gps_files(new_files);

      for (const auto &it : new_files)
	{
	  fprintf(stderr, "Import %s? (y/n) [y] ", it.c_str());
	  fflush(stderr);

	  char buf[64];
	  if (!fgets(buf, sizeof(buf), stdin))
	    return 0;

	  if (buf[0] == '\n' || (buf[0] == 'y' && buf[1] == '\n'))
	    {
	      arguments copy(args);

	      if (string_has_suffix(it, ".fit"))
		copy.push_back("--fit-file");
	      else if (string_has_suffix(it, ".tcx"))
		copy.push_back("--tcx-file");
	      else
		abort();

	      copy.push_back(it);

	      int ret = act_new(copy);
	      if (ret != 0)
		return ret;
	    }
	}
    }
  else
    return act_new(args);
}
