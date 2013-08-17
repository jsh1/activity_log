// -*- c-style: gnu -*-

#include "act-format.h"

#include "act-config.h"
#include "act-util.h"

#include <algorithm>
#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <xlocale.h>

#define INCHES_PER_METER 39.3701
#define FEET_PER_METER 3.2808399
#define YARDS_PER_METER 1.09361
#define MILES_PER_METER 0.000621371192
#define METERS_PER_MILE 1609.34
#define SECONDS_PER_DAY 86400
#define POUNDS_PER_KILO 2.2046

#define MINUTES_PER_MILE(x) ((1. / (x)) * (1. / (MILES_PER_METER * 60.)))
#define SECS_PER_MILE(x) ((1. /  (x)) * (1. / MILES_PER_METER))
#define SECS_PER_KM(x) ((1. /  (x)) * 1e3)

#define DEBUG_DATE_RANGES 0

namespace act {

void
format_date_time(std::string &str, time_t date)
{
  format_date_time(str, date, "%Y-%m-%d %H:%M:%S %z");
}

void
format_date_time(std::string &str, time_t date, const char *format)
{
  char buf[256];

  struct tm tm = {0};
  localtime_r(&date, &tm);

  strftime(buf, sizeof(buf), format, &tm);

  str.append(buf);
}

void
format_time(std::string &str, double dur,
	    bool include_frac, const char *suffix)
{
  char buf[256];

  if (!isfinite(dur))
    {
      strcpy(buf, "Inf");
    }
  else
    {
      if (!include_frac)
	dur = floor(dur + .5);

      if (dur > 3600)
	{
	  snprintf_l(buf, sizeof(buf), nullptr, "%d:%02d:%02d",
		     (int) floor(dur/3600), (int) fmod(floor(dur/60),60),
		     (int) fmod(dur, 60));
	}
      else if (dur > 60)
	{
	  snprintf_l(buf, sizeof(buf), nullptr, "%d:%02d",
		     (int) floor(dur/60), (int) fmod(dur, 60));
	}
      else
	{
	  snprintf_l(buf, sizeof(buf), nullptr, "%d", (int) dur);
	}

      double frac = dur - floor(dur);

      if (frac > 1e-4)
	{
	  size_t len = strlen(buf);
	  snprintf_l(buf + len, sizeof(buf) - len, nullptr,
		     ".%02d", (int) floor(frac * 10 + .5));
	}
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
  format_time(str, dur, true, nullptr);
}

void
format_number(std::string &str, double value)
{
  char buf[128];
  snprintf_l(buf, sizeof(buf), nullptr, "%g", value);

  str.append(buf);
}

void
format_distance(std::string &str, double dist, unit_type unit)
{
  const char *format = nullptr;

  switch (unit)
    {
    case unit_centimetres:
      format = "%.0f cm";
      dist = dist * 1e2;
      break;

    case unit_metres:
      format = "%.1f m";
      break;

    case unit_kilometres:
      format = "%.2f km";
      dist = dist * 1e-3;
      break;

    case unit_inches:
      format = "%.0f in";
      dist = dist * INCHES_PER_METER;
      break;

    case unit_feet:
      format = "%.0f feet";
      dist = dist * FEET_PER_METER;
      break;

    case unit_yards:
      format = "%.1f yd";
      dist = dist * YARDS_PER_METER;
      break;

    case unit_miles:
    default:
      format = "%.2f mi";
      dist = dist * MILES_PER_METER;
      break;
    }

  char buf[128];
  snprintf_l(buf, sizeof(buf), nullptr, format, dist);

  str.append(buf);
}

void
format_pace(std::string &str, double pace, unit_type unit)
{
  double dur = 0;
  const char *suffix = nullptr;

  switch (unit)
    {
    case unit_seconds_per_mile:
    default:
      suffix = " / mi";
      if (pace != 0)
	dur = SECS_PER_MILE(pace);
      else
	dur = HUGE_VAL;
      break;

    case unit_seconds_per_kilometre:
      suffix = " / km";
      if (pace != 0)
	dur = SECS_PER_KM(pace);
      else
	dur = HUGE_VAL;
      break;
    }

  format_time(str, dur, false, suffix);
}

void
format_speed(std::string &str, double speed, unit_type unit)
{
  double dist = 0;
  const char *format = nullptr;

  switch (unit)
    {
    case unit_metres_per_second:
      format = "%.1f m/s";
      dist = speed;
      break;

    case unit_kilometres_per_hour:
      format = "%.2f km/h";
      dist = speed * (3600/1e3);
      break;

    case unit_miles_per_hour:
    default:
      format = "%.2f mph";
      dist = speed * (3600/METERS_PER_MILE);
      break;
    }

  char buf[128];
  snprintf_l(buf, sizeof(buf), nullptr, format, dist);

  str.append(buf);
}

void
format_temperature(std::string &str, double temp, unit_type unit)
{
  const char *format = nullptr;

  switch (unit)
    {
    case unit_celsius:
    default:
      format = "%.f C";
      break;

    case unit_fahrenheit:
      format = "%.f F";
      temp = temp * 9/5 + 32;
      break;
    }

  char buf[64];

  snprintf_l(buf, sizeof(buf), nullptr, format, temp);

  str.append(buf);
}

void
format_weight(std::string &str, double weight, unit_type unit)
{
  const char *format = nullptr;

  switch (unit)
    {
    case unit_kilogrammes:
    default:
      format = "%.f kg";
      break;

    case unit_pounds:
      format = "%.f lb";
      weight = weight * POUNDS_PER_KILO;
      break;
    }

  char buf[64];

  snprintf_l(buf, sizeof(buf), nullptr, format, weight);

  str.append(buf);
}

void
format_fraction(std::string &str, double frac)
{
  char buf[32];

  snprintf_l(buf, sizeof(buf), nullptr, "%.1f/10", frac * 10);

  str.append(buf);
}

void
format_value(std::string &str, field_data_type type,
	     double value, unit_type unit)
{
  switch (type)
    {
    case type_number:
    case type_string:
      format_number(str, value);
      break;

    case type_duration:
      format_duration(str, value);
      break;

    case type_distance:
      if (unit == unit_unknown)
	unit = shared_config().default_distance_unit();
      format_distance(str, value, unit);
      break;

    case type_pace:
      if (unit == unit_unknown)
	unit = shared_config().default_pace_unit();
      format_pace(str, value, unit);
      break;

    case type_speed:
      if (unit == unit_unknown)
	unit = shared_config().default_speed_unit();
      format_speed(str, value, unit);
      break;

    case type_temperature:
      if (unit == unit_unknown)
	unit = shared_config().default_temperature_unit();
      format_temperature(str, value, unit);
      break;

    case type_fraction:
      format_fraction(str, value);
      break;

    case type_weight:
      if (unit == unit_unknown)
	unit = shared_config().default_weight_unit();
      format_weight(str, value, unit);
      break;

    case type_date:
      format_date_time(str, (time_t) value);
      break;

    case type_keywords:
      abort();
    }
}

void
format_keywords(std::string &str, const std::vector<std::string> &keys)
{
  bool first = true;

  for (auto it = keys.begin(); it != keys.end(); it++, first = false)
    {
      if (!first)
	str.push_back(' ');

      // FIXME: quoting?
      str.append(*it);
    }
}

namespace {

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
  while (month < 0)
    year--, month += 12;
  while (month > 11)
    year++, month -= 12;

  int seconds_in_month[12] = {31*SECONDS_PER_DAY, 0, 31*SECONDS_PER_DAY,
    30*SECONDS_PER_DAY, 31*SECONDS_PER_DAY, 30*SECONDS_PER_DAY,
    31*SECONDS_PER_DAY, 31*SECONDS_PER_DAY, 30*SECONDS_PER_DAY,
    31*SECONDS_PER_DAY, 30*SECONDS_PER_DAY, 31*SECONDS_PER_DAY};

  if (month != 1)
    return seconds_in_month[month];
  else
    return !leap_year_p(year) ? 28*SECONDS_PER_DAY : 29*SECONDS_PER_DAY;
}

int
day_of_week_index(const char *str)
{
  static const char *names[7] = {"sunday", "monday", "tuesday",
    "wednesday", "thursday", "friday", "saturday"};
  static const char *abbrevs[7] = {"sun", "mon", "tue", "wed", "thu",
     "fri", "sat"};

  for (int i = 0; i < 7; i++)
    {
      if (strcasecmp(str, names[i]) == 0 || strcasecmp(str, abbrevs[i]) == 0)
	return i;
    }

  return -1;
}

int
month_index(const char *str)
{
  static const char *names[12] = {"january", "february", "march",
    "april", "may", "june", "july", "august", "september", "october",
    "november", "december"};

  static const char *abbrevs[12] = {"jan", "feb", "mar", "apr", "may",
    "jun", "jul", "aug", "sep", "oct", "nov", "dec"};

  for (int i = 0; i < 12; i++)
    {
      if (strcasecmp(str, names[i]) == 0 || strcasecmp(str, abbrevs[i]) == 0)
	return i;
    }

  return -1;
}

size_t
skip_whitespace(const std::string &str, size_t idx)
{
  size_t i = idx;

  while (i < str.size() && isspace_l(str[i], nullptr))
    i++;

  return i;
}

size_t
skip_whitespace_and_dashes(const std::string &str, size_t idx)
{
  size_t i = idx;

  while (i < str.size() && (str[i] == '-' || isspace_l(str[i], nullptr)))
    i++;

  return i;
}

size_t
next_token(const std::string &str, size_t idx, std::string &token)
{
  size_t i = idx;
  while (i < str.size() && isalnum_l(str[i], nullptr))
    i++;

  if (i > idx)
    token = str.substr(idx, i - idx);
  else
    token.clear();

  return i;
}

bool
check_trailer(const std::string &str, size_t idx)
{
  while (idx < str.size())
    {
      if (!isspace_l(str[idx], nullptr))
	{
	  if (!shared_config().silent())
	    fprintf(stderr, "Error: trailing garbage in string: \"%s\"\n", str.c_str());
	  return false;
	}

      idx++;
    }

  return true;
}

int
parse_decimal(const std::string &str, size_t &idx, size_t max_digits)
{
  int value = 0;

  size_t i = idx;
  size_t max_i = std::min(str.size(), idx + max_digits);

  while (i < max_i && isdigit_l(str[i], nullptr))
    {
      value = value * 10 + str[i] - '0';
      i++;
    }

  if (i == idx)
    return -1;

  idx = i;
  return value;
}

double
parse_decimal_fraction(const std::string &str, size_t &idx)
{
  double value = 0;
  double base = 1;

  size_t i = idx;

  while (i < str.size() && isdigit_l(str[i], nullptr))
    {
      value = value * 10 + str[i] - '0';
      base = base * 10;
      i++;
    }

  if (i == idx)
    return -1;

  idx = i;
  return value / base;
}

bool
parse_number(const std::string &str, size_t &idx, double &value)
{
  const char *ptr = str.c_str() + idx;
  char *end_ptr;

  value = strtod_l(ptr, &end_ptr, nullptr);

  if ((value == 0 && end_ptr == ptr) || !isfinite(value))
    return false;

  idx = end_ptr - ptr;

  return true;
}

struct parsable_unit
{
  const char *word_list;
  unit_type unit;
  double multiplier;
  double offset;
};

bool
parse_unit(const parsable_unit *units, const std::string &str,
	   size_t &idx, double &value, unit_type &unit)
{
  char buf[128];

  size_t i = idx;
  while (i < str.size() && (isalpha_l(str[i], nullptr) || str[i] == '/'))
    i++;

  size_t len = i - idx;
  if (len + 1 > sizeof(buf))
    return false;

  memcpy(buf, str.c_str() + idx, len);
  buf[len] = 0;

  for (const parsable_unit *uptr = units; uptr->word_list; uptr++)
    {
      if (matches_word_list(buf, uptr->word_list))
	{
	  value = value * uptr->multiplier + uptr->offset;
	  unit = uptr->unit;
	  idx += len;
	  return true;
	}
    }

  /* Apply default unit conversion if none specified. */

  for (const parsable_unit *uptr = units; uptr->word_list; uptr++)
    {
      if (uptr->unit == unit)
	{
	  value = value * uptr->multiplier + uptr->offset;
	  return true;
	}
    }

  return false;
}

bool
parse_date(const std::string &str, size_t &idx,
	   struct tm *tm, time_t *range_ptr)
{
  /* Possible date formats:

	today
	yesterday
	N days ago
	last N days
	this week
	last week
	this month
	last month
	last N months
	this year
	last year
	last N years
	DAY			-- monday, etc
	last DAY		-- monday, etc
	MONTH D+		-- July 7
	MONTH			-- July
	YYYY			-- 2013
	YYYY-MM			-- 2013-07
	YYYY-MM-DD		-- 2013-07-18  */

  std::string token;

  idx = skip_whitespace(str, idx);
  idx = next_token(str, idx, token);

  if (token.size() == 0)
    return false;

  if (!isdigit_l(token[0], nullptr))
    {
      time_t now = time(nullptr);
      struct tm now_tm = {0};
      localtime_r(&now, &now_tm);

      tm->tm_mday = now_tm.tm_mday;
      tm->tm_mon = now_tm.tm_mon;
      tm->tm_year = now_tm.tm_year;

      const char *tstr = token.c_str();

      if (strcasecmp(tstr, "today") == 0)
	{
	  *range_ptr = SECONDS_PER_DAY;
	  return true;
	}
      else if (strcasecmp(tstr, "yesterday") == 0)
	{
	  tm->tm_mday--;
	  *range_ptr = SECONDS_PER_DAY;
	  return true;
	}
      else if (strcasecmp(tstr, "this") == 0 || strcasecmp(tstr, "last") == 0)
	{
	  int delta = strcasecmp(tstr, "this") == 0 ? 0 : -1;
	  int range_scale = 1;

	  idx = skip_whitespace_and_dashes(str, idx);
	  idx = next_token(str, idx, token);

	  if (token.size() == 0)
	    return false;

	  if (delta == -1 && isdigit_l(token[0], nullptr))
	    {
	      /* last N ... */

	      char *end;
	      long n = strtol_l(token.c_str(), &end, 10, nullptr);
	      if ((n == 0 && errno == EINVAL)
		  || (end - token.c_str()) != token.size())
		return false;

	      delta = (int) -n;
	      range_scale = (int) n;

	      tm->tm_hour = now_tm.tm_hour;
	      tm->tm_min = now_tm.tm_min;
	      tm->tm_sec = now_tm.tm_sec;
	      tm->tm_gmtoff = now_tm.tm_gmtoff;
	      tm->tm_isdst = now_tm.tm_isdst;

	      idx = skip_whitespace_and_dashes(str, idx);
	      idx = next_token(str, idx, token);

	      if (token.size() == 0)
		return false;
	    }

	  const char *tstr = token.c_str();

	  if (strcasecmp(tstr, "day") == 0
	      || strcasecmp(tstr, "days") == 0)
	    {
	      tm->tm_mday += delta;
	      *range_ptr = SECONDS_PER_DAY * range_scale;
	      return true;
	    }
	  else if (strcasecmp(tstr, "week") == 0
		   || strcasecmp(tstr, "weeks") == 0)
	    {
	      int dow = now_tm.tm_wday - shared_config().start_of_week();
	      if (dow < 0) dow += 7;
	      else if (dow >= 7) dow -= 7;
 	      tm->tm_mday -= dow;
	      tm->tm_mday += delta * 7;
	      *range_ptr = SECONDS_PER_DAY * 7 * range_scale;
	      return true;
	    }
	  else if (strcasecmp(tstr, "month") == 0
		   || strcasecmp(tstr, "months") == 0)
	    {
	      tm->tm_mday = 1;
	      tm->tm_mon += delta;
	      *range_ptr = seconds_in_month(tm->tm_year+1900, tm->tm_mon);
	      // FIXME: bogus multiplication by range_scale
	      *range_ptr *= range_scale;
	      return true;
	    }
	  else if (strcasecmp(tstr, "year") == 0
		   || strcasecmp(tstr, "years") == 0)
	    {
	      tm->tm_mon = 0;
	      tm->tm_mday = 1;
	      tm->tm_year += delta;
	      *range_ptr = seconds_in_year(tm->tm_year+1900);
	      // FIXME: bogus multiplication by range_scale
	      *range_ptr *= range_scale;
	      return true;
	    }
	  else
	    {
	      int idx = day_of_week_index(tstr);
	      if (idx >= 0)
		{
		  tm->tm_mday += idx - now_tm.tm_wday;
		  // "last DAY" subtracts a week if day is after today
		  if (delta < 0)
		    tm->tm_mday += idx >= now_tm.tm_wday ? -7 : 0;
		  *range_ptr = SECONDS_PER_DAY;
		  return true;
		}
	    }
	}
      else
	{
	  int idx;

	  idx = day_of_week_index(tstr);
	  if (idx >= 0)
	    {
	      tm->tm_mday += idx - now_tm.tm_wday;
	      // "DAY" always picks the last day (except today)
	      tm->tm_mday += idx > now_tm.tm_wday ? -7 : 0;
	      *range_ptr = SECONDS_PER_DAY;
	      return true;
	    }

	  idx = month_index(tstr);
	  if (idx >= 0)
	    {
	      tm->tm_mon = idx;

	      /* Speculatively try to parse "MONTH D+". */

	      size_t tidx = skip_whitespace_and_dashes(str, idx);
	      next_token(str, tidx, token);

	      if (token.size() != 0 && isdigit_l(token[0], nullptr))
		{
		  long n = strtol_l(token.c_str(), nullptr, 10, nullptr);

		  if (n > 0)
		    {
		      tm->tm_mday = n;
		      *range_ptr = SECONDS_PER_DAY;
		      return true;
		    }
		}

	      tm->tm_mday = 1;
	      *range_ptr = seconds_in_month(tm->tm_year+1900, tm->tm_mon);
	      return true;
	    }

	  return false;
	}
    }
  else
    {
      /* Check for "N day[s] ago". */

      if ((str[idx] == ' ' || str[idx] == '-')
	  && (str[idx+1] == 'd' || str[idx+1] == 'D'))
	{
	  size_t tidx = idx + 1;
	  std::string token1;
	  tidx = next_token(str, tidx, token1);

	  tidx = skip_whitespace_and_dashes(str, tidx);
	  std::string token2;
	  tidx = next_token(str, tidx, token2);

	  if (strcasecmp(token2.c_str(), "ago") == 0)
	    {
	      // FIXME: also handle "N {week,month,year}[s] ago"

	      if (strcasecmp(token1.c_str(), "day") == 0
		  || strcasecmp(token1.c_str(), "days") == 0)
		{
		  idx = tidx;

		  tidx = 0;
		  int n = parse_decimal(token, tidx, 100);
		  if (tidx != token.size())
		    return false;

		  time_t now = time(nullptr);
		  struct tm now_tm = {0};
		  localtime_r(&now, &now_tm);
				      
		  tm->tm_mday = now_tm.tm_mday;
		  tm->tm_mon = now_tm.tm_mon;
		  tm->tm_year = now_tm.tm_year;

		  tm->tm_mday -= n;
		  *range_ptr = SECONDS_PER_DAY;
		  return true;
		}
	    }
	}

      if (token.size() == 4)
	{
	  /* YYYY... */

	  size_t tidx = 0;
	  int year = parse_decimal(token, tidx, 4);
	  if (tidx != 4)
	    return false;

	  tm->tm_year = year - 1900;
	  tm->tm_mon = 0;
	  tm->tm_mday = 1;

	  if (str[idx] != '-')
	    {
	      *range_ptr = seconds_in_year(year);
	      return true;
	    }

	  idx = next_token(str, idx + 1, token);
	  if (token.size() != 2 || !isdigit_l(token[0], nullptr))
	    return false;

	  tidx = 0;
	  int month = parse_decimal(token, tidx, 2);
	  if (tidx != 2)
	    return false;

	  tm->tm_mon = month - 1;

	  if (str[idx] != '-')
	    {
	      *range_ptr = seconds_in_month(year, month);
	      return true;
	    }

	  idx = next_token(str, idx + 1, token);
	  if (token.size() != 2 || !isdigit_l(token[0], nullptr))
	    return false;

	  tidx = 0;
	  int day = parse_decimal(token, tidx, 2);
	  if (tidx != 2)
	    return false;

	  tm->tm_mday = day;
	  *range_ptr = SECONDS_PER_DAY;
	  return true;
	}
    }

  return false;
}

bool
parse_date_time(const std::string &str, size_t &idx,
		time_t *date_ptr, time_t *range_ptr)
{
  struct tm tm = {0};
  tm.tm_isdst = -1;
  bool is_utc = false;
  time_t range = 0;

  /* Check for "now". */

  {
    const char *ptr = str.c_str() + idx;

    if ((ptr[0] == 'n' || ptr[0] == 'N')
	&& (ptr[1] == 'o' || ptr[1] == 'O')
	&& (ptr[2] == 'w' || ptr[2] == 'W')
	&& (ptr[3] == 0 || isspace_l(ptr[3], nullptr)
	    || ispunct_l(ptr[3], nullptr)))
      {
	*date_ptr = time(nullptr);
	if (range_ptr)
	  *range_ptr = 1;
	idx += 3;
	return true;
      }
  }

  if (!parse_date(str, idx, &tm, &range))
    return false;

  idx = skip_whitespace(str, idx);

  if (range == SECONDS_PER_DAY && isdigit_l(str[idx], nullptr))
    {
      int hours = 0, minutes = 0, seconds = 0;

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

	      /* If no zone information, assume local time. Otherwise
		 add the zone offset and convert from UTC to time_t. */

	      if (idx + 4 < str.size() && (str[idx] == '+' || str[idx] == '-'))
		{
		  int sign = str[idx++] == '+' ? 1 : -1;
		  int zone_hrs = parse_decimal(str, idx, 2);
		  int zone_mins = parse_decimal(str, idx, 2);
		  hours -= sign * zone_hrs;
		  minutes -= sign * zone_mins;
		  is_utc = true;
		}
	    }
	  else
	    range = 60;
	}
      else
	range = 3600;

      tm.tm_hour = hours;
      tm.tm_min = minutes;
      tm.tm_sec = seconds;
    }

  if (is_utc)
    *date_ptr = timegm(&tm);
  else
    *date_ptr = mktime(&tm);

  if (range_ptr)
    *range_ptr = range;

  return true;
}

} // anonymous namespace

/* Date format is "now" or "DATE [TIME]", where TIME is "[HH:MM[:SS]
   [AM|PM] [ZONE]" and ZONE is "[+-]HHMM". If no ZONE, local time is
   assumed. */

bool
parse_date_time(const std::string &str, time_t *date_ptr, time_t *range_ptr)
{
  size_t idx = skip_whitespace(str, 0);

  if (!parse_date_time(str, idx, date_ptr, range_ptr))
    return false;

  return check_trailer(str, idx);
}

bool
parse_date_range(const std::string &str, time_t *date_ptr, time_t *range_ptr)
{
  size_t idx = skip_whitespace(str, 0);

  time_t now = time(nullptr);

  time_t date = now, range = 1;

  if (str[idx] != '.' && str[idx+1] != '.'
      && !parse_date_time(str, idx, &date, &range))
    {
      return false;
    }

  if (str[idx] == '.' && str[idx+1] == '.')
    {
      idx += 2;

      time_t date1 = 0, range1 = 1;

      if (idx != str.size()
	  && !isspace_l(str[idx], nullptr)
	  && !parse_date_time(str, idx, &date1, &range1))
	{
	  return false;
	}

      time_t date0 = date, range0 = range;

      date = std::min(date0, date1);
      range = std::max(date0 + range0, date1 + range1) - date;
    }

  *date_ptr = date;
  *range_ptr = range;

  if (DEBUG_DATE_RANGES)
    {
      fprintf(stderr, "date range: %s\n", str.c_str());
      struct tm tm;
      localtime_r(date_ptr, &tm);
      char buf[128];
      strftime(buf, sizeof(buf), "%F %R %z", &tm);
      fprintf(stderr, "  from: %s\n", buf);
      time_t to = *date_ptr + *range_ptr;
      localtime_r(&to, &tm);
      strftime(buf, sizeof(buf), "%F %R %z", &tm);
      fprintf(stderr, "    to: %s\n", buf);
    }

  return check_trailer(str, idx);
}

bool
parse_time(const std::string &str, size_t &idx, double *dur_ptr)
{
  int hours = 0, minutes = 0, seconds = 0;
  double seconds_frac = 0;

  hours = parse_decimal(str, idx, 4);
  if (hours < 0)
    return false;

  if (idx < str.size() && str[idx] == ':')
    {
      idx++;

      minutes = parse_decimal(str, idx, 4);
      if (minutes < 0)
	return false;

      if (idx < str.size() && str[idx] == ':')
	{
	  idx++;

	  seconds = parse_decimal(str, idx, 4);
	  if (seconds < 0)
	    return false;
	}
      else
	seconds = minutes, minutes = hours, hours = 0;
    }
  else
    seconds = hours, hours = 0;

  if (str[idx] == '.')
    {
      idx++;

      seconds_frac = parse_decimal_fraction(str, idx);
      if (seconds_frac < 0)
	return false;
    }

  *dur_ptr = (hours * 60 + minutes) * 60 + seconds + seconds_frac;

  return true;
}

bool
parse_date_interval(const std::string &str, date_interval *interval_ptr)
{
  /* Possible interval formats:

	day|daily
	week|weekly
	month|monthly
	year|yearly
	N day[s]
	N week[s]
	N month[s]
	N year[s]  */

  size_t idx = skip_whitespace(str, 0);

  std::string token;

  idx = next_token(str, idx, token);

  if (token.size() == 0)
    return false;

  date_interval::unit_type unit = date_interval::days;
  int count = 1;

  if (isdigit_l(token[0], nullptr))
    {
      size_t tidx = 0;
      count = parse_decimal(token, tidx, 100);
      if (tidx != token.size())
	return false;

      idx = skip_whitespace_and_dashes(str, idx);
      next_token(str, idx, token);

      if (token.size() == 0)
	return false;
    }

  const char *tstr = token.c_str();

  if (matches_word_list(tstr, "day\0days\0daily\0"))
    unit = date_interval::days;
  else if (matches_word_list(tstr, "week\0weeks\0weekly\0"))
    unit = date_interval::weeks;
  else if (matches_word_list(tstr, "month\0months\0monthly\0"))
    unit = date_interval::months;
  else if (matches_word_list(tstr, "year\0years\0yearly\0"))
    unit = date_interval::years;
  else
    return false;

  if (interval_ptr)
    *interval_ptr = date_interval(unit, count);

  return true;
}

bool
parse_duration(const std::string &str, double *dur_ptr)
{
  size_t idx = skip_whitespace(str, 0);

  if (!parse_time(str, idx, dur_ptr))
    return false;

  return check_trailer(str, idx);
}

bool
parse_number(const std::string &str, double *value_ptr)
{
  size_t idx = skip_whitespace(str, 0);

  if (!parse_number(str, idx, *value_ptr))
    return false;

  return check_trailer(str, idx);
}

bool
parse_distance(const std::string &str, double *dist_ptr, unit_type *unit_ptr)
{
  size_t idx = skip_whitespace(str, 0);

  double value;
  if (!parse_number(str, idx, value))
    return false;

  idx = skip_whitespace(str, idx);

  static const parsable_unit distance_units[] =
    {
      {"cm\0centimetres\0centimetre\0centimeters\0centimeter\0",
       unit_centimetres, .01},
      {"m\0metres\0metre\0meters\0meter\0", unit_metres, 1},
      {"km\0kilometres\0kilometre\0kilometers\0kilometer\0",
       unit_kilometres, 1000},
      {"in\0inches\0inch\0", unit_inches, 1/INCHES_PER_METER},
      {"ft\0feet\0foot\0", unit_feet, 1/FEET_PER_METER},
      {"yd\0yards\0yard\0", unit_yards, 1/YARDS_PER_METER},
      {"mi\0mile\0miles\0", unit_miles, 1/MILES_PER_METER},
      {0}
    };

  unit_type unit = shared_config().default_distance_unit();

  parse_unit(distance_units, str, idx, value, unit);

  *dist_ptr = value;

  if (unit_ptr)
    *unit_ptr = unit;

  return check_trailer(str, idx);
}

bool
parse_pace(const std::string &str, double *pace_ptr, unit_type *unit_ptr)
{
  double value;

  size_t idx = skip_whitespace(str, 0);

  if (!parse_time(str, idx, &value))
    return false;

  value = 1/value;
  unit_type unit = unit_seconds_per_mile;

  idx = skip_whitespace(str, idx);

  if (idx < str.size() && str[idx] == '/')
    {
      idx = skip_whitespace(str, idx + 1);

      static const parsable_unit pace_units[] =
	{
	  {"mi\0mile\0", unit_seconds_per_mile, 1/MILES_PER_METER},
	  {"km\0kilometre\0kilometer\0", unit_seconds_per_kilometre, 1000},
	  {0}
	};

      unit = shared_config().default_pace_unit();

      if (!parse_unit(pace_units, str, idx, value, unit))
	return false;
    }
  else
    value = value * (1/MILES_PER_METER);

  *pace_ptr = value;

  if (unit_ptr)
    *unit_ptr = unit;

  return check_trailer(str, idx);
}

bool
parse_speed(const std::string &str, double *speed_ptr, unit_type *unit_ptr)
{
  size_t idx = skip_whitespace(str, 0);

  double value;
  if (!parse_number(str, idx, value))
    return false;

  idx = skip_whitespace(str, idx);

  static const parsable_unit speed_units[] =
    {
      {"m/s\0mps\0", unit_metres_per_second, 1},
      {"km/h\0kmh\0", unit_kilometres_per_hour, 1000/3600.},
      {"mph\0", unit_miles_per_hour, METERS_PER_MILE/3600.},
      {0}
    };

  unit_type unit = shared_config().default_speed_unit();

  parse_unit(speed_units, str, idx, value, unit);

  *speed_ptr = value;

  if (unit_ptr)
    *unit_ptr = unit;

  return check_trailer(str, idx);
}

bool
parse_temperature(const std::string &str, double *temp_ptr,
		  unit_type *unit_ptr)
{
  size_t idx = skip_whitespace(str, 0);

  double value;
  if (!parse_number(str, idx, value))
    return false;

  idx = skip_whitespace(str, idx);

  static const parsable_unit temp_units[] =
    {
      {"c\0celsius\0centigrade\0", unit_celsius, 1},
      {"f\0fahrenheit\0", unit_fahrenheit, 5/9., -160*9.},
      {0}
    };

  unit_type unit = shared_config().default_temperature_unit();

  parse_unit(temp_units, str, idx, value, unit);

  *temp_ptr = value;

  if (unit_ptr)
    *unit_ptr = unit;

  return check_trailer(str, idx);
}

bool
parse_weight(const std::string &str, double *weight_ptr, unit_type *unit_ptr)
{
  size_t idx = skip_whitespace(str, 0);

  double value;
  if (!parse_number(str, idx, value))
    return false;

  idx = skip_whitespace(str, idx);

  static const parsable_unit weight_units[] =
    {
      {"kg\0kilos\0kilogram\0kilograms\0kilogramme\0kilogrammes\0",
       unit_kilogrammes, 1},
      {"lb\0lbs\0pound\0pounds\0", unit_pounds, 1/POUNDS_PER_KILO},
      {0}
    };

  unit_type unit = shared_config().default_weight_unit();

  parse_unit(weight_units, str, idx, value, unit);

  *weight_ptr = value;

  if (unit_ptr)
    *unit_ptr = unit;

  return check_trailer(str, idx);
}

bool
parse_fraction(const std::string &str, double *frac_ptr)
{
  double value;

  size_t idx = skip_whitespace(str, 0);

  if (!parse_number(str, idx, value))
    return false;

  idx = skip_whitespace(str, idx);

  if (idx < str.size())
    {
      if (str[idx] == '/')
	{
	  idx++;
	  double denom;
	  if (!parse_number(str, idx, denom))
	    return false;
	  value = value / denom;
	}
      else if (str[idx] == '%')
	{
	  idx++;
	  value = value / 100;
	}
    }

  *frac_ptr = value;

  return check_trailer(str, idx);
}

bool
parse_keywords(const std::string &str, std::vector<std::string> *keys_ptr)
{
  size_t idx = skip_whitespace(str, 0);

  while (idx < str.size())
    {
      std::string key;
      while (idx < str.size() && !isspace_l(str[idx], nullptr))
	key.push_back(str[idx++]);

      if (key.size() > 0)
	{
	  size_t k = keys_ptr->size();
	  keys_ptr->resize(k + 1);
	  using std::swap;
	  swap((*keys_ptr)[k], key);
	}

      idx = skip_whitespace(str, idx);
    }

  return true;
}

bool
parse_value(const std::string &str, field_data_type type,
	    double *value_ptr, unit_type *unit_ptr)
{
  if (unit_ptr)
    *unit_ptr = unit_unknown;

  switch (type)
    {
    case type_number:
    case type_string:
      return parse_number(str, value_ptr);

    case type_duration:
      return parse_duration(str, value_ptr);

    case type_distance:
      return parse_distance(str, value_ptr, unit_ptr);

    case type_pace:
      return parse_pace(str, value_ptr, unit_ptr);

    case type_speed:
      return parse_speed(str, value_ptr, unit_ptr);

    case type_temperature:
      return parse_temperature(str, value_ptr, unit_ptr);

    case type_fraction:
      return parse_fraction(str, value_ptr);

    case type_weight:
      return parse_weight(str, value_ptr, unit_ptr);

    case type_date: {
      time_t time = 0;
      if (parse_date_time(str, &time, nullptr))
	{
	  *value_ptr = time;
	  return true;
	}
      return false; }

    case type_keywords:
      return false;
    }

  return false;
}

} // namespace act
