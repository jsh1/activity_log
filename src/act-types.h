// -*- c-style: gnu -*-

#ifndef ACT_TYPES_H
#define ACT_TYPES_H

#include <string>
#include <time.h>

namespace act {

enum field_id
{
  // ordered by canonical output order
  field_date,
  field_gps_file,
  field_activity,
  field_type,
  field_course,
  field_duration,
  field_distance,
  field_pace,
  field_max_pace,
  field_speed,
  field_max_speed,
  field_effort,
  field_quality,
  field_resting_hr,
  field_average_hr,
  field_max_hr,
  field_calories,
  field_equipment,
  field_temperature,
  field_dew_point,
  field_weather,
  field_weight,
  field_keywords,
  field_custom,
};

enum field_data_type
{
  type_string,
  type_number,
  type_date,
  type_duration,
  type_distance,
  type_pace,
  type_speed,
  type_temperature,
  type_fraction,
  type_weight,
  type_keywords,
};

field_id lookup_field_id(const char *field_name);
const char *canonical_field_name(field_id id);

field_data_type lookup_field_data_type(field_id id);

bool canonicalize_field_string(field_data_type type, std::string &value);

enum unit_type
{
  unit_unknown,

  // time units
  unit_seconds,

  // distance units
  unit_centimetres,
  unit_metres,
  unit_kilometres,
  unit_inches,
  unit_feet,
  unit_yards,
  unit_miles,

  // pace units
  unit_seconds_per_mile,
  unit_seconds_per_kilometre,

  // speed units
  unit_metres_per_second,
  unit_kilometres_per_hour,
  unit_miles_per_hour,

  // temperature units
  unit_celsius,
  unit_fahrenheit,

  // mass units
  unit_kilogrammes,
  unit_pounds,
};

struct date_range
{
  time_t start;
  time_t length;

  date_range(time_t s, time_t l);

  bool contains(time_t t) const;
};

struct date_interval
{
  enum unit_type
    {
      days, weeks, months, years
    };

  unit_type unit;
  int count;

  date_interval(unit_type u, int n);

  int date_index(time_t date) const;
};

// implementation

inline
date_range::date_range(time_t s, time_t l)
: start(s),
  length(l)
{
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

} // namespace act

#endif /* ACT_TYPES_H */
