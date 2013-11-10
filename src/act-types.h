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

#ifndef ACT_TYPES_H
#define ACT_TYPES_H

#include "act-base.h"

#include <string>
#include <time.h>

namespace act {

enum class field_id
{
  // ordered by canonical output order
  date,
  gps_file,
  activity,
  type,
  course,
  duration,
  elapsed_time,
  distance,
  ascent,
  descent,
  pace,
  max_pace,
  speed,
  max_speed,
  effort,
  quality,
  resting_hr,
  average_hr,
  max_hr,
  calories,
  equipment,
  temperature,
  dew_point,
  weather,
  weight,
  keywords,
  vdot,					// read-only
  points,
  custom,
};

enum class field_data_type
{
  string,
  number,
  date,
  duration,
  distance,
  pace,
  speed,
  temperature,
  fraction,
  weight,
  heart_rate,
  keywords,
  unknown = string,
};

field_id lookup_field_id(const char *field_name);
const char *canonical_field_name(field_id id);

bool field_read_only_p(field_id id);

field_data_type lookup_field_data_type(field_id id);

bool canonicalize_field_string(field_data_type type, std::string &value);

enum class unit_type
{
  unknown,

  // time units
  seconds,

  // distance units
  centimetres,
  metres,
  kilometres,
  inches,
  feet,
  yards,
  miles,

  // pace units
  seconds_per_mile,
  seconds_per_kilometre,

  // speed units
  metres_per_second,
  kilometres_per_hour,
  miles_per_hour,

  // temperature units
  celsius,
  fahrenheit,

  // mass units
  kilogrammes,
  pounds,

  // heart-rate units
  beats_per_minute,
  percent_hr_reserve,
  percent_hr_max,
};

struct date_range
{
  time_t start;
  time_t length;

  date_range(time_t s, time_t l);

  static date_range infinity();

  bool contains(time_t t) const;
};

struct date_interval
{
  enum class unit_type
    {
      days, weeks, months, years
    };

  unit_type unit;
  int count;

  date_interval(unit_type u, int n);

  int date_index(time_t date) const;
  void append_date(std::string &str, int x) const;
};

struct location
{
  double latitude;
  double longitude;

  location();
  location(double lat, double lng);
};

void mix(location &a, const location &b, const location &c, double f);

struct location_size
{
  double latitude;
  double longitude;

  location_size();
  location_size(double lat, double lng);
};

struct location_region
{
  location center;
  location_size size;

  location_region();
  location_region(const location &cen, const location_size &size);
};

// implementation

inline
date_range::date_range(time_t s, time_t l)
: start(s),
  length(l)
{
}

inline date_range
date_range::infinity()
{
  return date_range(0, LONG_MAX);
}

inline bool
date_range::contains(time_t t) const
{
  time_t delta = t - start;
  return delta >= 0 && delta < length;
}

inline
date_interval::date_interval(unit_type u, int n)
: unit(u),
  count(n)
{
}

inline
location::location()
: latitude(0),
  longitude(0)
{
}

inline
location::location(double lat, double lng)
: latitude(lat),
  longitude(lng)
{
}

inline
location_size::location_size()
: latitude(0),
  longitude(0)
{
}

inline
location_size::location_size(double lat, double lng)
: latitude(lat),
  longitude(lng)
{
}

inline
location_region::location_region()
{
}

inline
location_region::location_region(const location &cen,
				 const location_size &sz)
: center(cen),
  size(sz)
{
}

inline void
mix(location &a, const location &b, const location &c, double f)
{
  mix(a.latitude, b.latitude, c.latitude, f);
  mix(a.longitude, b.longitude, c.longitude, f);
}

} // namespace act

#endif /* ACT_TYPES_H */
