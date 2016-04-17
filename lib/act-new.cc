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
#include "act-format.h"
#include "act-gps-activity.h"
#include "act-intensity-points.h"
#include "act-util.h"

#include <cmath>

namespace act {

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
  opt_avg_hr,
  opt_max_hr,
  opt_calories,
  opt_weight,
  opt_temperature,
  opt_dew_point,
  opt_weather,
  opt_quality,
  opt_effort,
  opt_points,
  opt_gps_file,
  opt_field,
  // import options
  opt_import_all,
};

field_id
option_field_id(option_id opt)
{
  switch (opt)
    {
    case opt_date:
      return field_id::date;
    case opt_activity:
      return field_id::activity;
    case opt_type:
      return field_id::type;
    case opt_course:
      return field_id::course;
    case opt_keyword:
      return field_id::keywords;
    case opt_equipment:
      return field_id::equipment;
    case opt_distance:
      return field_id::distance;
    case opt_duration:
      return field_id::duration;
    case opt_pace:
      return field_id::pace;
    case opt_speed:
      return field_id::speed;
    case opt_max_pace:
      return field_id::max_pace;
    case opt_max_speed:
      return field_id::max_speed;
    case opt_resting_hr:
      return field_id::resting_hr;
    case opt_avg_hr:
      return field_id::avg_hr;
    case opt_max_hr:
      return field_id::max_hr;
    case opt_calories:
      return field_id::calories;
    case opt_weight:
      return field_id::weight;
    case opt_temperature:
      return field_id::temperature;
    case opt_dew_point:
      return field_id::dew_point;
    case opt_weather:
      return field_id::weather;
    case opt_quality:
      return field_id::quality;
    case opt_effort:
      return field_id::effort;
    case opt_points:
      return field_id::points;
    case opt_gps_file:
      return field_id::gps_file;
    case opt_field:
      return field_id::custom;
    case opt_edit:
    case opt_import_all:
      abort();
    }
}

const arguments::option new_options[] =
{
  {opt_edit, "edit", 'e', nullptr, "Open new file in editor."},
  {opt_date, "date", 0, "DATE", nullptr},
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
  {opt_avg_hr, "avg-hr", 0, "AVG-HR"},
  {opt_max_hr, "max-hr", 0, "MAX-HR"},
  {opt_calories, "calories", 0, "CALORIES"},
  {opt_weight, "weight", 0, "WEIGHT"},
  {opt_temperature, "temperature", 0, "TEMP"},
  {opt_dew_point, "dew-point", 0, "TEMP"},
  {opt_weather, "weather", 0, "WEATHER"},
  {opt_quality, "quality", 0, "QUALITY-RATIO"},
  {opt_effort, "effort", 0, "EFFORT-RATIO"},
  {opt_points, "points", 0, "POINTS"},
  {opt_gps_file, "gps-file", 0, "GPS-FILE"},
  {opt_field, "field", 'f', "NAME:VALUE", "Define custom field."},
  {arguments::opt_eof}
};

const arguments::option import_options[] =
{
  {opt_import_all, "import-all", 0, nullptr, "Import all new GPS files."},
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
copy_gps_fields(activity_storage &a, const gps::activity &gps_data)
{
  bool changed = false;

  if (a.field_ptr("Date") == nullptr)
    {
      format_date_time(a["Date"], (time_t) gps_data.start_time(),
		       "%Y-%m-%d %H:%M:%S %z");
      changed = true;
    }

  if (gps_data.sport() != gps::activity::sport_type::unknown
      && a.field_ptr("Activity") == nullptr)
    {
      gps::activity::sport_type sport = gps_data.sport();
      std::string type;
      if (sport == gps::activity::sport_type::running)
	type = "run";
      else if (sport == gps::activity::sport_type::cycling)
	type = "bike";
      if (sport == gps::activity::sport_type::swimming)
	type = "swim";
      if (type.size() != 0)
	{
	  a["Activity"] = type;
	  changed = true;
	}
    }

  if (gps_data.total_duration() > 0
      && a.field_ptr("Duration") == nullptr)
    {
      // rounding to seconds, don't need fractional precision
      format_duration(a["Duration"], std::round(gps_data.total_duration()));
      changed = true;
    }

  if (gps_data.total_distance() > 0
      && a.field_ptr("Distance") == nullptr)
    {
      format_distance(a["Distance"],
		      gps_data.total_distance(), unit_type::miles);
      changed = true;
    }

  if (gps_data.has_speed()
      && a.field_ptr("Points") == nullptr)
    {
      // compute Daniels' intensity points

      double points = calculate_points(gps_data);

      if (points != 0)
	{
	  points = std::round(points * 10) * .1;
	  format_number(a["Points"], points);
	  changed = true;
	}
    }

  // Let other fields be read as needed.

  if (changed)
    a.increment_seed();
}

} // anonymous namespace

int
act_new(arguments &args)
{
  using std::swap;

  bool edit = false;

  activity_storage_ref storage (new activity_storage);

  while (1)
    {
      const char *opt_arg = nullptr;
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
	  if (parse_date_time(std::string(opt_arg), &date, nullptr))
	    format_date_time((*storage)["Date"], date);
	  break; }

	  // keyword arguments concatenate into existing values

	case opt_keyword:
	case opt_equipment:
	case opt_weather: {
	  field_id id = option_field_id((option_id)opt);
	  std::string &value = (*storage)[canonical_field_name(id)];
	  std::vector<std::string> keys;
	  parse_keywords(value, &keys);
	  keys.push_back(std::string(opt_arg));
	  format_keywords(value, keys);
	  break; }

	case opt_field: {
	  std::string arg(opt_arg);
	  std::string name, value;
	  size_t idx = arg.find_first_of(':');
	  if (idx != std::string::npos)
	    {
	      name = arg.substr(0, idx);
	      value = arg.substr(idx + 1, arg.size() - (idx + 1));
	    }
	  else
	    swap(name, arg);
	  swap((*storage)[name], value);
	  break; }

	  // GPS files have directories stripped

	case opt_gps_file:
	  if (const char *tem = strrchr(opt_arg, '/'))
	    opt_arg = tem + 1;
	  /* fall through */

	default: {
	  field_id id = option_field_id((option_id)opt);
	  std::string &value = (*storage)[canonical_field_name(id)];
	  value = opt_arg;
	  canonicalize_field_string(lookup_field_data_type(id), value);
	  break; }

	case arguments::opt_error:
	  fprintf(stderr, "Error: invalid argument: %s\n\n", opt_arg);
	  print_usage(args, false);
	  return 1;
	}
    }

  activity a (storage);
  
  if (const gps::activity *gps_data = a.gps_data())
    {
      copy_gps_fields(*storage, *gps_data);
    }

  if (storage->field_ptr("Points") == nullptr)
    {
      double points = calculate_points(a.speed(), a.duration());

      if (points != 0)
	{
	  points = std::round(points * 10) * .1;
	  format_number((*storage)["Points"], points);
	  storage->increment_seed();
	}
    }

  std::string filename;
  if (!a.make_filename(filename))
    return 1;

  storage->canonicalize_field_order();

  if (!storage->write_file(filename.c_str()))
    return 1;

  if (edit)
    {
#if ACT_COMMAND_LINE
      shared_config().edit_file(filename.c_str());
#endif
    }

  return 0;
}

int
act_import(arguments &args)
{
  bool import_all = false;

  while (1)
    {
      const char *opt_arg = nullptr;
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

} // namespace act
