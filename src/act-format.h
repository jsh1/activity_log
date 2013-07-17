// -*- c-style: gnu -*-

#ifndef ACT_FORMAT_H
#define ACT_FORMAT_H

#include "act-base.h"

#include <string>
#include <vector>

#include <time.h>

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

// string conversion functions

void format_date(std::string &str, time_t date);
void format_duration(std::string &str, double dur);
void format_distance(std::string &str, double dist, distance_unit unit);
void format_pace(std::string &str, double pace, pace_unit unit);
void format_speed(std::string &str, double speed, speed_unit unit);
void format_temperature(std::string &str, double temp, temperature_unit unit);
void format_fraction(std::string &str, double frac);
void format_keywords(std::string &str, const std::vector<std::string> &keys);

bool parse_date(const std::string &str, time_t *date_ptr, time_t *range_ptr);
bool parse_duration(const std::string &str, double *dur_ptr);
bool parse_distance(const std::string &str, double *dist_ptr,
  distance_unit *unit_ptr);
bool parse_pace(const std::string &str, double *pace_ptr,
  pace_unit *unit_ptr);
bool parse_speed(const std::string &str, double *speed_ptr,
  speed_unit *unit_ptr);
bool parse_temperature(const std::string &str, double *temp_ptr,
  temperature_unit *unit_ptr);
bool parse_fraction(const std::string &str, double *frac_ptr);
bool parse_keywords(const std::string &str,
  std::vector<std::string> *keys_ptr);

} // namespace act

#endif /* ACT_FORMAT_H */
