// -*- c-style: gnu -*-

#ifndef ACT_TYPES_H
#define ACT_TYPES_H

namespace act {

enum distance_unit
{
  unit_centimetres,
  unit_metres,
  unit_kilometres,
  unit_inches,
  unit_feet,
  unit_yards,
  unit_miles,
};

enum pace_unit
{
  unit_seconds_per_mile,
  unit_seconds_per_kilometre,
};

enum speed_unit
{
  unit_metres_per_second,
  unit_kilometres_per_hour,
  unit_miles_per_hour,
};

enum temperature_unit
{
  unit_celsius,
  unit_fahrenheit,
};

} // namespace act

#endif /* ACT_TYPES_H */
