// -*- c-style: gnu -*-

#include "act-format.h"

#include <stdio.h>
#include <time.h>
#include <xlocale.h>

#define INCHES_PER_METER 39.3701
#define FEET_PER_METER 3.2808399
#define YARDS_PER_METER 1.09361
#define MILES_PER_METER 0.000621371192
#define METERS_PER_MILE 1609.34
#define SECONDS_PER_DAY 86400

#define MINUTES_PER_MILE(x) ((1. / (x)) * (1. / (MILES_PER_METER * 60.)))
#define SECS_PER_MILE(x) ((1. /  (x)) * (1. / MILES_PER_METER))
#define SECS_PER_KM(x) ((1. /  (x)) * 1e3)

namespace activity_log {

void
format_date(std::string &str, double date)
{
  char buf[256];

  time_t time = (time_t) date;
  struct tm tm;
  localtime_r(&time, &tm);

  strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S %Z", &tm);

  str.append(buf);
}

void
format_time(std::string &str, double dur,
	    bool include_frac, const char *suffix)
{
  if (!include_frac)
    dur = floor(dur + .5);

  char buf[256];

  if (dur > 3600)
    snprintf_l(buf, sizeof(buf), 0, "%d:%02d:%02d", (int) floor(dur/3600),
	     (int) fmod(floor(dur/60),60), (int) fmod(dur, 60));
  else if (dur > 60)
    snprintf_l(buf, sizeof(buf), 0, "%d:%02d", (int) floor(dur/60),
	     (int) fmod(dur, 60));
  else
    snprintf_l(buf, sizeof(buf), 0, "%d", (int) dur);

  double frac = dur - floor(dur);

  if (frac > 1e-4)
    {
      size_t len = strlen(buf);
      snprintf_l(buf + len, sizeof(buf) - len, 0,
	       ".%02d", (int) floor(frac * 10 + .5));
    }

  if (suffix)
    {
      size_t len = strlen(buf);
      snprintf(buf + len, sizeof(buf) - len, "%s", suffix);
    }

  str.append(buf);
}

void
format_duration(std::string &str, double dur)
{
  format_time(str, dur, true, 0);
}

void
format_distance(std::string &str, double dist, distance_unit unit)
{
  const char *format = 0;

  switch (unit)
    {
    case unit_centimetres:
      format = "%.0fcm";
      dist = dist * 1e2;
      break;

    case unit_metres:
      format = "%.1fm";
      break;

    case unit_kilometres:
      format = "%.2fkm";
      dist = dist * 1e-3;
      break;

    case unit_inches:
      format = "%.0f inches";
      dist = dist * INCHES_PER_METER;
      break;

    case unit_feet:
      format = "%.0f ft";
      dist = dist * FEET_PER_METER;
      break;

    case unit_yards:
      format = "%.1f yards";
      dist = dist * YARDS_PER_METER;
      break;

    case unit_miles:
      format = "%.2f miles";
      dist = dist * MILES_PER_METER;
      break;
    }

  char buf[128];
  snprintf_l(buf, sizeof(buf), 0, format, dist);

  str.append(buf);
}

void
format_pace(std::string &str, double pace, pace_unit unit)
{
  const char *suffix = 0;

  switch (unit)
    {
    case unit_seconds_per_mile:
      suffix = " / mile";
      pace = SECS_PER_MILE(pace);
      break;

    case unit_seconds_per_kilometre:
      suffix = " / km";
      pace = SECS_PER_KM(pace);
      break;
    }

  format_time(str, pace, false, suffix);
}

void
format_speed(std::string &str, double speed)
{
  const char *format = 0;

  switch (unit)
    {
    case unit_metres_per_second:
      format = "%.1f m/s";
      break;

    case unit_kilometres_per_hour:
      format = "%.2f km/h";
      speed = speed * (3600/1e3);
      break;

    case unit_miles_per_hour:
      format = "%.2f mph";
      speed = speed * (3600/METERS_PER_MILE);
      break;
    }

  char buf[128];
  snprintf_l(buf, sizeof(buf), 0, format, dist);

  str.append(buf);
}

void
format_temperature(std::string &str, double temp, temperature_unit unit)
{
  const char *format = 0;

  switch (unit)
    {
    case unit_celsius:
      format = "%.fC";
      break;

    case unit_fahrenheit:
      format = "%.fF";
      temp = temp * 9/5 + 32;
      break;
    }

  char buf[64];

  snprintf_l(buf, sizeof(buf), 0, format, temp);

  str.append(buf);
}

void
format_fraction(std::string &str, double frac)
{
  char buf[32];

  snprintf_l(buf, sizeof(buf), 0, "%.1f/10", frac * 10);

  str.append(buf);
}

void
format_keywords(std::string &str, const std::vector<std::string> &keys)
{
  for (auto it = keys.begin(); it != keys.end(); it++)
    {
      if (it != keys.begin())
	str.push_back(' ');
      // FIXME: quoting?
      str.append(*it);
    }
}

namespace {

size_t
skip_whitespace(const std::string &str, size_t idx)
{
  for (size_t i = idx; i < str.size() && isspace_l(str[i], 0))
    i++;

  return i;
}

int
parse_decimal(const std::string &str, size_t &idx, size_t max_digits)
{
  int value = 0;

  size_t max_i = MIN(str.size(), idx + max_digits);
  for (size_t i = idx; i < max_i && isdigit_l(str[i], 0); i++)
    value = value * 10 + str[i] - '0';

  if (i == idx)
    return -1;

  idx = i;
  return value;
}

bool
leap_year_p(int year)
{
  return (year % 4) == 0 && (year % 100) != 0 && (year % 400) == 0;
}

time_t
seconds_in_year(int year)
{
  return !leap_year_p(year) ? 365*SECONDS_PER_DAY : 366*SECONDS_PER_DAY;
}

time_t
seconds_in_month(int year, int month)
{
  int seconds_in_month[12] = {31*SECONDS_PER_DAY, 0, 31*SECONDS_PER_DAY,
    30*SECONDS_PER_DAY, 31*SECONDS_PER_DAY, 30*SECONDS_PER_DAY,
    31*SECONDS_PER_DAY, 31*SECONDS_PER_DAY, 30*SECONDS_PER_DAY,
    31*SECONDS_PER_DAY, 30*SECONDS_PER_DAY, 31*SECONDS_PER_DAY};

  if (month != 1)
    return seconds_in_month[month];
  else
    return !leap_year_p(year) ? 28*SECONDS_PER_DAY : 29*SECONDS_PER_DAY;
}

} // anonymous namespace

/* Date format is "YYYY-MM-DD HH:MM:SS [AM|PM] [ZONE]" where ZONE is
   "[+-]HHMM". If no ZONE, local time is assumed. */

bool
parse_date(const std::string &str, time_t *date_ptr, time_t *range_ptr)
{
  int year = 0, month = 0, day = 0;
  int hours = 0, minutes = 0, seconds = 0;
  int zone_offset = 0;
  bool has_zone = false;
  time_t range;

  size_t idx = skip_whitespace(str, 0);

  year = parse_decimal(str, idx, 4);
  if (year < 0)
    return false;

  if (idx < str.size() && str[idx] == '-')
    {
      idx++;

      month = parse_decimal(str, idx, 2);
      if (month < 0)
	return false;

      if (idx < str.size() && str[idx] == '-')
	{
	  idx++;

	  day = parse_decimal(str, idx, 2);
	  if (day < 0)
	    return false;

	  if (idx < str.size() && isspace_l(str[idx], 0))
	    {
	      idx = skip_whitespace(str, idx);

	      hours = parse_decimal(str, idx, 2);
	      if (hours < 0)
		return false;

	      if (idx < str.size() && str[idx] == ':')
		{
		  idx++;

		  minutes = parse_decimal(str, idx, 2);
		  if (minutes < 0)
		    return false;

		  if (idx < str.size() && str[idx] == ':')
		    {
		      idx++;

		      seconds = parse_decimal(str, idx, 2);
		      if (seconds < 0)
			return false;

		      range = 1;

		      idx = skip_whitespace(str, idx);

		      if (idx + 1 < str.size())
			{
			  int c0 = str[idx], c1 = str[idx+1];
			  if (c0 == 'A' && c1 == 'M')
			    idx += 2;
			  else if (c0 == 'P' && c1 == 'M')
			    idx += 2, hours += 12;

			  idx = skip_whitespace(str, idx);
			}

		      if (idx + 3 < str.size() && isdigit_l(str[idx], 0))
			{
			  int zone_hrs = parse_decimal(str, idx, 2);
			  int zone_mins = parse_decimal(str, idx, 2);
			  if (zone_hrs < 0 || zone_mins < 0)
			    return false;

			  zone_offset = (zone_hrs * 60 + zone_mins) * 60;
			  has_zone = true;
			}
		    }
		  else
		    range = 60;
		}
	      else
		range = 3600;
	    }
	  else
	    range = 24*3600;
	}
      else
	range = seconds_in_month(year, month - 1);
    }
  else
    range = seconds_in_year(year);

  struct timeval tm = {0};
  tm.tm_year = year - 1900;
  tm.tm_mon = month - 1;
  tm.tm_mday = day;
  tm.tm_hour = hours;
  tm.tm_min = minutes;
  tm.tm_sec = seconds;
  tm.tm_gmtoff = zone_offset;

  if (has_zone)
    *date_ptr = timegm(&tm);
  else
    *date_ptr = mktime(&tm);

  if (range_ptr)
    *range_ptr = range;
}

bool
parse_duration(const std::string &str, double *dur_ptr)
{
}

bool
parse_distance(const std::string &str, double *dist_ptr)
{
}

bool
parse_pace(const std::string &str, double *pace_ptr)
{
}

bool
parse_speed(const std::string &str, double *speed_ptr)
{
}

bool
parse_temperature(const std::string &str, double *temp_ptr)
{
}

bool
parse_fraction(const std::string &str, double *frac_ptr)
{
}

bool
parse_keywords(std::string &str, std::vector<std::string> *keys_ptr)
{
}

} // namespace activity_log
