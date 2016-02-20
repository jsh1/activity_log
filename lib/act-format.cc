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

#define MINUTES_PER_MILE(x) (METERS_PER_MILE / ((x) * 60))
#define SECS_PER_MILE(x) (METERS_PER_MILE / (x))
#define SECS_PER_KM(x) (1e3 / (x))

#define DEBUG_DATE_RANGES 0

namespace act {

void
format_date_time(std::string &str, time_t date)
{
  format_date_time(str, date, "%Y-%m-%d %H:%M:%S");
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
  else if (dur > 10)
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
		     ".%02d", (int) floor(frac * 100 + .5));
	}
    }
  else
    {
      snprintf_l(buf, sizeof(buf), nullptr, "%d ms", (int) round(dur * 1000));
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

  if (unit == unit_type::unknown)
    unit = shared_config().default_distance_unit();

again:
  switch (unit)
    {
    case unit_type::centimetres:
      if (dist < 5e-3)
	{
	  unit = unit_type::millimetres;
	  goto again;
	}
      format = "%.1f cm";
      dist = dist * 1e2;
      break;

    case unit_type::millimetres:
      format = "%.0f mm";
      dist = dist * 1e3;
      break;

    case unit_type::metres:
      if (dist < 0.5)
	{
	  unit = unit_type::centimetres;
	  goto again;
	}
      format = dist < 10 ? "%.2f m" : "%.1f m";
      break;

    case unit_type::kilometres:
      if (dist < 5e-2)
	{
	  unit = unit_type::metres;
	  goto again;
	}
      dist = dist * 1e-3;
      format = dist < 10 ? "%.2f km" : "%.1f km";
      break;

    case unit_type::inches:
      if (dist < (1 / INCHES_PER_METER) * 0.5)
	{
	  unit = unit_type::millimetres;
	  goto again;
	}
      format = "%.0f in";
      dist = dist * INCHES_PER_METER;
      break;

    case unit_type::feet:
      format = "%.0f ft";
      dist = dist * FEET_PER_METER;
      break;

    case unit_type::yards:
      if (dist < (1 / YARDS_PER_METER) * 0.5)
	{
	  unit = unit_type::inches;
	  goto again;
	}
      format = "%.1f yd";
      dist = dist * YARDS_PER_METER;
      break;

    case unit_type::miles:
    default:
      if (dist < METERS_PER_MILE * 0.5)
	{
	  unit = unit_type::metres;
	  goto again;
	}
      dist = dist * MILES_PER_METER;
      format = dist < 10 ? "%.2f mi" : "%.1f mi";
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

  if (unit == unit_type::unknown)
    unit = shared_config().default_pace_unit();

  switch (unit)
    {
    case unit_type::seconds_per_mile:
    default:
      suffix = " /mi";
      if (pace != 0)
	dur = SECS_PER_MILE(pace);
      else
	dur = HUGE_VAL;
      break;

    case unit_type::seconds_per_kilometre:
      suffix = " /km";
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

  if (unit == unit_type::unknown)
    unit = shared_config().default_speed_unit();

  switch (unit)
    {
    case unit_type::metres_per_second:
      format = "%.1f m/s";
      dist = speed;
      break;

    case unit_type::kilometres_per_hour:
      format = "%.2f km/h";
      dist = speed * (3600/1e3);
      break;

    case unit_type::miles_per_hour:
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

  if (unit == unit_type::unknown)
    unit = shared_config().default_temperature_unit();

  switch (unit)
    {
    case unit_type::celsius:
    default:
      format = "%.f C";
      break;

    case unit_type::fahrenheit:
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

  if (unit == unit_type::unknown)
    unit = shared_config().default_weight_unit();

  switch (unit)
    {
    case unit_type::kilogrammes:
    default:
      format = "%.f kg";
      break;

    case unit_type::pounds:
      format = "%.f lb";
      weight = weight * POUNDS_PER_KILO;
      break;
    }

  char buf[64];

  snprintf_l(buf, sizeof(buf), nullptr, format, weight);

  str.append(buf);
}

void
format_heart_rate(std::string &str, double value, unit_type unit)
{
  const char *format = "%.3g bpm";

  const config &c = shared_config();

  switch (unit)
    {
    case unit_type::percent_hr_reserve:
      if (c.resting_hr() != 0 && c.max_hr() != 0)
	{
	  format = "%.3g %%hrr";
	  value = (value - c.resting_hr()) / (c.max_hr() - c.resting_hr()) * 100;
	}
      break;

    case unit_type::percent_hr_max:
      if (c.max_hr() != 0)
	{
	  format = "%.3g %%max";
	  value = value / c.max_hr() * 100;
	}
      break;

    default:
      break;
    }

  char buf[64];

  snprintf_l(buf, sizeof(buf), nullptr, format, value);

  str.append(buf);
}

void
format_cadence(std::string &str, double value, unit_type unit)
{
  char buf[64];

  if (floor(value) == value)
    snprintf_l(buf, sizeof(buf), nullptr, "%d spm", (int) value);
  else
    snprintf_l(buf, sizeof(buf), nullptr, "%.1f spm", value);

  str.append(buf);
}

void
format_efficiency(std::string &str, double value, unit_type unit)
{
  const char *format = nullptr;

  if (unit == unit_type::unknown)
    unit = shared_config().default_efficiency_unit();

  switch (unit)
    {
    case unit_type::beats_per_metre:
      format = "%.f beats/m";
      break;

    case unit_type::beats_per_kilometre:
      format = "%.f beats/km";
      value = value * 1000;
      break;

    case unit_type::beats_per_mile:
    default:
      format = "%.f beats/mi";
      value = value * METERS_PER_MILE;
      break;
    }

  char buf[64];

  snprintf_l(buf, sizeof(buf), nullptr, format, value);

  str.append(buf);
}
void
format_fraction(std::string &str, double frac)
{
  char buf[32];

  snprintf_l(buf, sizeof(buf), nullptr, "%.1f%%", frac * 100);

  str.append(buf);
}

void
format_value(std::string &str, field_data_type type,
	     double value, unit_type unit)
{
  switch (type)
    {
    case field_data_type::number:
    case field_data_type::string:
      format_number(str, value);
      break;

    case field_data_type::duration:
      format_duration(str, value);
      break;

    case field_data_type::distance:
      format_distance(str, value, unit);
      break;

    case field_data_type::pace:
      format_pace(str, value, unit);
      break;

    case field_data_type::speed:
      format_speed(str, value, unit);
      break;

    case field_data_type::temperature:
      format_temperature(str, value, unit);
      break;

    case field_data_type::fraction:
      format_fraction(str, value);
      break;

    case field_data_type::weight:
      format_weight(str, value, unit);
      break;

    case field_data_type::heart_rate:
      format_heart_rate(str, value, unit);
      break;

    case field_data_type::cadence:
      format_cadence(str, value, unit);
      break;

    case field_data_type::efficiency:
      format_efficiency(str, value, unit);
      break;

    case field_data_type::date:
      format_date_time(str, (time_t) value);
      break;

    case field_data_type::keywords:
      abort();
    }
}

void
format_keywords(std::string &str, const std::vector<std::string> &keys)
{
  bool first = true;

  for (const auto &it : keys)
    {
      if (!first)
	str.push_back(' ');
      else
	first = false;

      // FIXME: quoting?
      str.append(it);
    }
}

namespace {

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

namespace {

struct parsable_unit
{
  const char *word_list;
  unit_type unit;
  double multiplier;
  double offset;
};

static const parsable_unit time_units[] =
{
  {"s\0", unit_type::seconds, 1},
  {"ms\0", unit_type::seconds, 1e-3},
  {"us\0", unit_type::seconds, 1e-6},
  {"ns\0", unit_type::seconds, 1e-9},
  {0}
};

static const parsable_unit distance_units[] =
{
  {"cm\0centimetres\0centimetre\0centimeters\0centimeter\0",
   unit_type::centimetres, 1e-2},
  {"mm\0millmetres\0milliimetre\0millimeters\0millimeter\0",
   unit_type::millimetres, 1e-3},
  {"m\0metres\0metre\0meters\0meter\0", unit_type::metres, 1},
  {"km\0kilometres\0kilometre\0kilometers\0kilometer\0",
   unit_type::kilometres, 1e3},
  {"in\0inches\0inch\0", unit_type::inches, 1/INCHES_PER_METER},
  {"ft\0feet\0foot\0", unit_type::feet, 1/FEET_PER_METER},
  {"yd\0yards\0yard\0", unit_type::yards, 1/YARDS_PER_METER},
  {"mi\0mile\0miles\0", unit_type::miles, 1/MILES_PER_METER},
  {0}
};

static const parsable_unit pace_units[] =
{
  {"mi\0mile\0", unit_type::seconds_per_mile, METERS_PER_MILE},
  {"km\0kilometre\0kilometer\0", unit_type::seconds_per_kilometre, 1000},
  {0}
};

static const parsable_unit speed_units[] =
{
  {"m/s\0mps\0", unit_type::metres_per_second, 1},
  {"km/h\0kmh\0", unit_type::kilometres_per_hour, 1000/3600.},
  {"mph\0", unit_type::miles_per_hour, METERS_PER_MILE/3600.},
  {0}
};

static const parsable_unit temperature_units[] =
{
  {"c\0celsius\0centigrade\0", unit_type::celsius, 1},
  {"f\0fahrenheit\0", unit_type::fahrenheit, 5/9., -160/9.},
  {0}
};

static const parsable_unit weight_units[] =
{
  {"kg\0kilos\0kilogram\0kilograms\0kilogramme\0kilogrammes\0",
   unit_type::kilogrammes, 1},
  {"lb\0lbs\0pound\0pounds\0", unit_type::pounds, 1/POUNDS_PER_KILO},
  {0}
};

static const parsable_unit cadence_units[] =
{
  {"spm\0", unit_type::steps_per_minute, 1},
  {0}
};

static const parsable_unit efficiency_units[] =
{
  {"beats/m\0beats/metre\0beats/meter\0", unit_type::beats_per_metre, 1},
  {"beats/km\0beats/kilometre\0beats/kilometer\0",
   unit_type::beats_per_kilometre, 1e-3},
  {"beats/mi\0beats/mile\0", unit_type::beats_per_mile, MILES_PER_METER},
  {0}
};

bool
parse_unit(const parsable_unit *units, const std::string &str,
	   size_t &idx, double &value, unit_type &unit)
{
  char buf[128];

  size_t i = idx;
  while (i < str.size() && (isalpha_l(str[i], nullptr)
			    || str[i] == '/' || str[i] == '%'))
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

} // anonymous namespace

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
		      tm->tm_mday = (int)n;
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

	      /* We're going to ignore any zone information, we assume
		 that it's always best to display the local time from
		 when the activity was created. The easiest way to do
		 that is to ignore the zone and convert to UTC from our
		 current local timezone. */

	      if (idx + 4 < str.size() && (str[idx] == '+' || str[idx] == '-'))
		{
		  idx++;
		  parse_decimal(str, idx, 4);
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

  bool single_value = false;

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
    {
      seconds = hours, hours = 0;
      single_value = true;
    }
  if (str[idx] == '.')
    {
      idx++;

      seconds_frac = parse_decimal_fraction(str, idx);
      if (seconds_frac < 0)
	return false;
    }

  if (single_value)
    {
      /* Check for "INTEGER[.DECIMAL] UNIT" form. */

      double value = seconds + seconds_frac;
      unit_type unit = unit_type::unknown;

      if (parse_unit(time_units, str, idx, value, unit))
	{
	  *dur_ptr = value;
	  return true;
	}
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

  date_interval::unit_type unit = date_interval::unit_type::days;
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
    unit = date_interval::unit_type::days;
  else if (matches_word_list(tstr, "week\0weeks\0weekly\0"))
    unit = date_interval::unit_type::weeks;
  else if (matches_word_list(tstr, "month\0months\0monthly\0"))
    unit = date_interval::unit_type::months;
  else if (matches_word_list(tstr, "year\0years\0yearly\0"))
    unit = date_interval::unit_type::years;
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
  unit_type unit = unit_type::seconds_per_mile;

  idx = skip_whitespace(str, idx);

  if (idx < str.size() && str[idx] == '/')
    {
      idx = skip_whitespace(str, idx + 1);

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

  unit_type unit = shared_config().default_temperature_unit();

  parse_unit(temperature_units, str, idx, value, unit);

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

  unit_type unit = shared_config().default_weight_unit();

  parse_unit(weight_units, str, idx, value, unit);

  *weight_ptr = value;

  if (unit_ptr)
    *unit_ptr = unit;

  return check_trailer(str, idx);
}

bool
parse_heart_rate(const std::string &str,
		 double *value_ptr, unit_type *unit_ptr)
{
  size_t idx = skip_whitespace(str, 0);

  double value;
  if (!parse_number(str, idx, value))
    return false;

  idx = skip_whitespace(str, idx);

  unit_type unit = unit_type::beats_per_minute;

  const config &c = shared_config();

  parsable_unit hr_units[4];

  hr_units[0].word_list = "bpm\0";
  hr_units[0].unit = unit_type::beats_per_minute;
  hr_units[0].multiplier = 1;
  hr_units[0].offset = 0;

  if (c.max_hr() != 0)
    {
      hr_units[1].word_list = "%max\0";
      hr_units[1].unit = unit_type::percent_hr_reserve;
      hr_units[1].multiplier = .01 * c.max_hr();
      hr_units[1].offset = 0;

      if (c.resting_hr() != 0)
	{
	  hr_units[2].word_list = "%hrr\0";
	  hr_units[2].unit = unit_type::percent_hr_reserve;
	  hr_units[2].multiplier = .01 * (c.max_hr() - c.resting_hr());
	  hr_units[2].offset = c.resting_hr();

	  hr_units[3].word_list = 0;
	}
      else
	hr_units[2].word_list = 0;
    }
  else
    hr_units[1].word_list = 0;

  parse_unit(hr_units, str, idx, value, unit);

  *value_ptr = value;

  if (unit_ptr)
    *unit_ptr = unit;

  return check_trailer(str, idx);
}

bool
parse_cadence(const std::string &str, double *value_ptr, unit_type *unit_ptr)
{
  size_t idx = skip_whitespace(str, 0);

  double value;
  if (!parse_number(str, idx, value))
    return false;

  idx = skip_whitespace(str, idx);

  unit_type unit = unit_type::steps_per_minute;

  parse_unit(cadence_units, str, idx, value, unit);

  *value_ptr = value;

  if (unit_ptr)
    *unit_ptr = unit;

  return check_trailer(str, idx);
}

bool
parse_efficiency(const std::string &str,
		 double *value_ptr, unit_type *unit_ptr)
{
  size_t idx = skip_whitespace(str, 0);

  double value;
  if (!parse_number(str, idx, value))
    return false;

  idx = skip_whitespace(str, idx);

  unit_type unit = shared_config().default_efficiency_unit();

  parse_unit(efficiency_units, str, idx, value, unit);

  *value_ptr = value;

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
    *unit_ptr = unit_type::unknown;

  switch (type)
    {
    case field_data_type::number:
    case field_data_type::string:
      return parse_number(str, value_ptr);

    case field_data_type::duration:
      return parse_duration(str, value_ptr);

    case field_data_type::distance:
      return parse_distance(str, value_ptr, unit_ptr);

    case field_data_type::pace:
      return parse_pace(str, value_ptr, unit_ptr);

    case field_data_type::speed:
      return parse_speed(str, value_ptr, unit_ptr);

    case field_data_type::temperature:
      return parse_temperature(str, value_ptr, unit_ptr);

    case field_data_type::fraction:
      return parse_fraction(str, value_ptr);

    case field_data_type::weight:
      return parse_weight(str, value_ptr, unit_ptr);

    case field_data_type::heart_rate:
      return parse_heart_rate(str, value_ptr, unit_ptr);

    case field_data_type::cadence:
      return parse_cadence(str, value_ptr, unit_ptr);

    case field_data_type::efficiency:
      return parse_efficiency(str, value_ptr, unit_ptr);

    case field_data_type::date: {
      time_t time = 0;
      if (parse_date_time(str, &time, nullptr))
	{
	  *value_ptr = time;
	  return true;
	}
      return false; }

    case field_data_type::keywords:
      return false;
    }

  return false;
}

bool
parse_unit(const std::string &str, field_data_type type, unit_type &unit)
{
  size_t idx = 0;
  double value = 0;

  if ((type == field_data_type::unknown
       || type == field_data_type::distance)
      && parse_unit(distance_units, str, idx, value, unit))
    return true;

  if ((type == field_data_type::unknown
       || type == field_data_type::pace)
      && parse_unit(pace_units, str, idx, value, unit))
    return true;

  if ((type == field_data_type::unknown
       || type == field_data_type::speed)
      && parse_unit(speed_units, str, idx, value, unit))
    return true;

  if ((type == field_data_type::unknown
       || type == field_data_type::temperature)
      && parse_unit(temperature_units, str, idx, value, unit))
    return true;

  if ((type == field_data_type::unknown
       || type == field_data_type::weight)
      && parse_unit(weight_units, str, idx, value, unit))
    return true;

  if ((type == field_data_type::unknown
       || type == field_data_type::cadence)
      && parse_unit(cadence_units, str, idx, value, unit))
    return true;

  if ((type == field_data_type::unknown
       || type == field_data_type::efficiency)
      && parse_unit(efficiency_units, str, idx, value, unit))
    return true;

  return false;
}

} // namespace act
