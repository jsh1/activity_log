// -*- c-style: gnu -*-

#include "act-types.h"

#include "act-config.h"
#include "act-format.h"
#include "act-util.h"

#include <xlocale.h>

namespace act {

field_id
lookup_field_id(const char *str)
{
  switch (tolower_l(str[0], nullptr))
    {
    case 'a':
      if (strcasecmp(str, "activity") == 0)
	return field_activity;
      else if (strcasecmp(str, "average_hr") == 0)
	return field_average_hr;
      break;

    case 'c':
      if (strcasecmp(str, "calories") == 0)
	return field_calories;
      else if (strcasecmp(str, "course") == 0)
	return field_course;
      break;

    case 'd':
      if (strcasecmp(str, "date") == 0)
	return field_date;
      else if (strcasecmp(str, "dew-point") == 0)
	return field_dew_point;
      else if (strcasecmp(str, "distance") == 0)
	return field_distance;
      else if (strcasecmp(str, "duration") == 0)
	return field_duration;
      break;

    case 'e':
      if (strcasecmp(str, "effort") == 0)
	return field_effort;
      else if (strcasecmp(str, "equipment") == 0)
	return field_equipment;
      break;

    case 'g':
      if (strcasecmp(str, "gps-file") == 0)
	return field_gps_file;
      break;

    case 'k':
      if (strcasecmp(str, "keywords") == 0)
	return field_keywords;
      break;

    case 'm':
      if (strcasecmp(str, "max-hr") == 0)
	return field_max_hr;
      else if (strcasecmp(str, "max-pace") == 0)
	return field_max_pace;
      else if (strcasecmp(str, "max-speed") == 0)
	return field_max_speed;
      break;

    case 'p':
      if (strcasecmp(str, "pace") == 0)
	return field_pace;
      break;

    case 'q':
      if (strcasecmp(str, "quality") == 0)
	return field_quality;
      break;

    case 'r':
      if (strcasecmp(str, "resting-hr") == 0)
	return field_resting_hr;
      break;

    case 't':
      if (strcasecmp(str, "temperature") == 0)
	return field_temperature;
      else if (strcasecmp(str, "type") == 0)
	return field_type;
      break;

    case 'w':
      if (strcasecmp(str, "weather") == 0)
	return field_weather;
      else if (strcasecmp(str, "weight") == 0)
	return field_weight;
      break;
    }

  return field_custom;
}

const char *
canonical_field_name(field_id id)
{
  switch (id)
    {
    case field_activity:
      return "Activity";
    case field_average_hr:
      return "Average-HR";
    case field_calories:
      return "Calories";
    case field_course:
      return "Course";
    case field_custom:
      return 0;
    case field_date:
      return "Date";
    case field_dew_point:
      return "Dew-Point";
    case field_distance:
      return "Distance";
    case field_duration:
      return "Duration";
    case field_effort:
      return "Effort";
    case field_equipment:
      return "Equipment";
    case field_gps_file:
      return "GPS-File";
    case field_keywords:
      return "Keywords";
    case field_max_hr:
      return "Max-HR";
    case field_max_pace:
      return "Max-Pace";
    case field_max_speed:
      return "Max-Speed";
    case field_pace:
      return "Pace";
    case field_quality:
      return "Quality";
    case field_resting_hr:
      return "Resting-HR";
    case field_speed:
      return "Speed";
    case field_temperature:
      return "Temperature";
    case field_type:
      return "Type";
    case field_weather:
      return "Weather";
    case field_weight:
      return "Weight";
    }
}

field_data_type
lookup_field_data_type(const field_id id)
{
  switch (id)
    {
    case field_activity:
    case field_course:
    case field_gps_file:
    case field_type:
    case field_custom:
      return type_string;
    case field_average_hr:
    case field_calories:
    case field_max_hr:
    case field_resting_hr:
      return type_number;
    case field_date:
      return type_date;
    case field_distance:
      return type_distance;
    case field_duration:
      return type_duration;
    case field_effort:
    case field_quality:
      return type_fraction;
    case field_equipment:
    case field_keywords:
    case field_weather:
      return type_keywords;
    case field_max_pace:
    case field_pace:
      return type_pace;
    case field_max_speed:
    case field_speed:
      return type_speed;
    case field_dew_point:
    case field_temperature:
      return type_temperature;
    case field_weight:
      return type_weight;
    }
}

bool
canonicalize_field_string(field_data_type type, std::string &str)
{
  switch (type)
    {
    case type_string:
      return true;

    case type_number: {
      double value;
      if (parse_number(str, &value))
	{
	  str.clear();
	  format_number(str, value);
	  return true;
	}
      break; }

    case type_date: {
      time_t date;
      if (parse_date_time(str, &date, nullptr))
	{
	  str.clear();
	  format_date_time(str, date);
	  return true;
	}
      break; }

    case type_duration: {
      double dur;
      if (parse_duration(str, &dur))
	{
	  str.clear();
	  format_duration(str, dur);
	  return true;
	}
      break; }

    case type_distance: {
      double dist;
      unit_type unit;
      if (parse_distance(str, &dist, &unit))
	{
	  str.clear();
	  format_distance(str, dist, unit);
	  return true;
	}
      break; }

    case type_pace: {
      double pace;
      unit_type unit;
      if (parse_pace(str, &pace, &unit))
	{
	  str.clear();
	  format_pace(str, pace, unit);
	  return true;
	}
      break; }

    case type_speed: {
      double speed;
      unit_type unit;
      if (parse_speed(str, &speed, &unit))
	{
	  str.clear();
	  format_speed(str, speed, unit);
	  return true;
	}
      break; }

    case type_temperature: {
      double temp;
      unit_type unit;
      if (parse_temperature(str, &temp, &unit))
	{
	  str.clear();
	  format_temperature(str, temp, unit);
	  return true;
	}
      break; }

    case type_weight: {
      double temp;
      unit_type unit;
      if (parse_weight(str, &temp, &unit))
	{
	  str.clear();
	  format_weight(str, temp, unit);
	  return true;
	}
      break; }

    case type_fraction: {
      double value;
      if (parse_fraction(str, &value))
	{
	  str.clear();
	  format_fraction(str, value);
	  return true;
	}
      break; }

    case type_keywords: {
      std::vector<std::string> keys;
      if (parse_keywords(str, &keys))
	{
	  str.clear();
	  format_keywords(str, keys);
	  return true;
	}
      break; }
    }

  return false;
}

} // namespace act
