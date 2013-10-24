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
	return field_id::activity;
      else if (strcasecmp(str, "average-hr") == 0)
	return field_id::average_hr;
      break;

    case 'c':
      if (strcasecmp(str, "calories") == 0)
	return field_id::calories;
      else if (strcasecmp(str, "course") == 0)
	return field_id::course;
      break;

    case 'd':
      if (strcasecmp(str, "date") == 0)
	return field_id::date;
      else if (strcasecmp(str, "dew-point") == 0)
	return field_id::dew_point;
      else if (strcasecmp(str, "distance") == 0)
	return field_id::distance;
      else if (strcasecmp(str, "duration") == 0)
	return field_id::duration;
      break;

    case 'e':
      if (strcasecmp(str, "effort") == 0)
	return field_id::effort;
      else if (strcasecmp(str, "equipment") == 0)
	return field_id::equipment;
      break;

    case 'g':
      if (strcasecmp(str, "gps-file") == 0)
	return field_id::gps_file;
      break;

    case 'k':
      if (strcasecmp(str, "keywords") == 0)
	return field_id::keywords;
      break;

    case 'm':
      if (strcasecmp(str, "max-hr") == 0)
	return field_id::max_hr;
      else if (strcasecmp(str, "max-pace") == 0)
	return field_id::max_pace;
      else if (strcasecmp(str, "max-speed") == 0)
	return field_id::max_speed;
      break;

    case 'p':
      if (strcasecmp(str, "pace") == 0)
	return field_id::pace;
      else if (strcasecmp(str, "points") == 0)
	return field_id::points;
      break;

    case 'q':
      if (strcasecmp(str, "quality") == 0)
	return field_id::quality;
      break;

    case 'r':
      if (strcasecmp(str, "resting-hr") == 0)
	return field_id::resting_hr;
      break;

    case 't':
      if (strcasecmp(str, "temperature") == 0)
	return field_id::temperature;
      else if (strcasecmp(str, "type") == 0)
	return field_id::type;
      break;

    case 'v':
      if (strcasecmp(str, "vdot") == 0)
	return field_id::vdot;
      break;

    case 'w':
      if (strcasecmp(str, "weather") == 0)
	return field_id::weather;
      else if (strcasecmp(str, "weight") == 0)
	return field_id::weight;
      break;
    }

  return field_id::custom;
}

const char *
canonical_field_name(field_id id)
{
  switch (id)
    {
    case field_id::activity:
      return "Activity";
    case field_id::average_hr:
      return "Average-HR";
    case field_id::calories:
      return "Calories";
    case field_id::course:
      return "Course";
    case field_id::custom:
      return 0;
    case field_id::date:
      return "Date";
    case field_id::dew_point:
      return "Dew-Point";
    case field_id::distance:
      return "Distance";
    case field_id::duration:
      return "Duration";
    case field_id::effort:
      return "Effort";
    case field_id::equipment:
      return "Equipment";
    case field_id::gps_file:
      return "GPS-File";
    case field_id::keywords:
      return "Keywords";
    case field_id::max_hr:
      return "Max-HR";
    case field_id::max_pace:
      return "Max-Pace";
    case field_id::max_speed:
      return "Max-Speed";
    case field_id::pace:
      return "Pace";
    case field_id::points:
      return "Points";
    case field_id::quality:
      return "Quality";
    case field_id::resting_hr:
      return "Resting-HR";
    case field_id::speed:
      return "Speed";
    case field_id::temperature:
      return "Temperature";
    case field_id::type:
      return "Type";
    case field_id::vdot:
      return "VDOT";
    case field_id::weather:
      return "Weather";
    case field_id::weight:
      return "Weight";
    }
}

bool
field_read_only_p(field_id id)
{
  switch (id)
    {
    case field_id::vdot:
      return true;

    default:
      return false;
    }
}

field_data_type
lookup_field_data_type(const field_id id)
{
  switch (id)
    {
    case field_id::activity:
    case field_id::course:
    case field_id::gps_file:
    case field_id::type:
    case field_id::custom:
      return field_data_type::string;
    case field_id::calories:
    case field_id::vdot:
    case field_id::points:
      return field_data_type::number;
    case field_id::date:
      return field_data_type::date;
    case field_id::distance:
      return field_data_type::distance;
    case field_id::duration:
      return field_data_type::duration;
    case field_id::effort:
    case field_id::quality:
      return field_data_type::fraction;
    case field_id::equipment:
    case field_id::keywords:
    case field_id::weather:
      return field_data_type::keywords;
    case field_id::max_pace:
    case field_id::pace:
      return field_data_type::pace;
    case field_id::max_speed:
    case field_id::speed:
      return field_data_type::speed;
    case field_id::dew_point:
    case field_id::temperature:
      return field_data_type::temperature;
    case field_id::weight:
      return field_data_type::weight;
    case field_id::average_hr:
    case field_id::max_hr:
    case field_id::resting_hr:
      return field_data_type::heart_rate;
    }
}

bool
canonicalize_field_string(field_data_type type, std::string &str)
{
  switch (type)
    {
    case field_data_type::string:
      return true;

    case field_data_type::number: {
      double value;
      if (parse_number(str, &value))
	{
	  str.clear();
	  format_number(str, value);
	  return true;
	}
      break; }

    case field_data_type::date: {
      time_t date;
      if (parse_date_time(str, &date, nullptr))
	{
	  str.clear();
	  format_date_time(str, date);
	  return true;
	}
      break; }

    case field_data_type::duration: {
      double dur;
      if (parse_duration(str, &dur))
	{
	  str.clear();
	  format_duration(str, dur);
	  return true;
	}
      break; }

    case field_data_type::distance: {
      double dist;
      unit_type unit;
      if (parse_distance(str, &dist, &unit))
	{
	  str.clear();
	  format_distance(str, dist, unit);
	  return true;
	}
      break; }

    case field_data_type::pace: {
      double pace;
      unit_type unit;
      if (parse_pace(str, &pace, &unit))
	{
	  str.clear();
	  format_pace(str, pace, unit);
	  return true;
	}
      break; }

    case field_data_type::speed: {
      double speed;
      unit_type unit;
      if (parse_speed(str, &speed, &unit))
	{
	  str.clear();
	  format_speed(str, speed, unit);
	  return true;
	}
      break; }

    case field_data_type::temperature: {
      double temp;
      unit_type unit;
      if (parse_temperature(str, &temp, &unit))
	{
	  str.clear();
	  format_temperature(str, temp, unit);
	  return true;
	}
      break; }

    case field_data_type::weight: {
      double temp;
      unit_type unit;
      if (parse_weight(str, &temp, &unit))
	{
	  str.clear();
	  format_weight(str, temp, unit);
	  return true;
	}
      break; }

    case field_data_type::heart_rate: {
      double value;
      unit_type unit;
      if (parse_heart_rate(str, &value, &unit))
	{
	  str.clear();
	  format_heart_rate(str, value, unit_type::beats_per_minute);
	  return true;
	}
      break; }

    case field_data_type::fraction: {
      double value;
      if (parse_fraction(str, &value))
	{
	  str.clear();
	  format_fraction(str, value);
	  return true;
	}
      break; }

    case field_data_type::keywords: {
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

namespace {

int
days_since_1970(const struct tm &tm)
{
  /* Adapted from Linux kernel's mktime(). */

  int year = tm.tm_year + 1900;
  int month = tm.tm_mon - 1;	/* 0..11 -> 11,12,1..10 */
  if (month < 0)
    month += 12, year -= 1;
  int day = tm.tm_mday;

  return ((year/4 - year/100 + year/400 + 367*month/12 + day)
	  + year*365 - 719499);
}

void
append_days_date(std::string &str, int days)
{
  time_t date = days * (time_t) (24*60*60);
  struct tm tm = {0};
  localtime_r(&date, &tm);

  char buf[128];
  strftime_l(buf, sizeof(buf), "%F", &tm, nullptr);
  str.append(buf);
}

} // anonymous namespace

int
date_interval::date_index(time_t date) const
{
  struct tm tm = {0};
  localtime_r(&date, &tm);

  int x = 0;

  switch (unit)
    {
    case unit_type::days:
      return days_since_1970(tm) / count;

    case unit_type::weeks: {
      // 1970-01-01 was a thursday.
      static int week_offset = 4 - shared_config().start_of_week();
      x = (days_since_1970(tm) + week_offset) / 7;
      break; }

    case unit_type::months:
      x = (tm.tm_year - 70) * 12 + tm.tm_mon;
      break;

    case unit_type::years:
      x = tm.tm_year - 70;
      break;
    }

  return x / count;
}

void
date_interval::append_date(std::string &str, int x) const
{
  x = x * count;

  switch (unit)
    {
    case unit_type::days:
      append_days_date(str, x);
      break;

    case unit_type::weeks: {
      static int week_offset = 4 - shared_config().start_of_week();
      int days = x * 7 - week_offset;
      append_days_date(str, days);
      break; }

    case unit_type::months: {
      int month = x % 12;
      int year = 1970 + x / 12;
      char buf[128];
      static const char *names[] = {"January", "February", "March",
	"April", "May", "June", "July", "August", "September",
	"October", "November", "December"};
      snprintf_l(buf, sizeof(buf), nullptr, "%s %04d", names[month], year);
      str.append(buf);
      break; }

    case unit_type::years: {
      char buf[64];
      snprintf_l(buf, sizeof(buf), nullptr, "%d", 1970 + x);
      str.append(buf);
      break; }
    }
}

} // namespace act
