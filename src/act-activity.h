// -*- c-style: gnu -*-

#ifndef ACT_ACTIVITY_H
#define ACT_ACTIVITY_H

#include "act-base.h"

#include "act-format.h"

#include <string>
#include <vector>

#include <time.h>

namespace act {

class activity
{
public:
  enum field_id
    {
      field_activity,
      field_average_hr,
      field_calories,
      field_course,
      field_custom,
      field_date,
      field_distance,
      field_duration,
      field_effort,
      field_equipment,
      field_fit_file,
      field_keywords,
      field_max_hr,
      field_max_pace,
      field_max_speed,
      field_pace,
      field_quality,
      field_resting_hr,
      field_speed,
      field_tcx_file,
      field_temperature,
      field_type,
      field_weather,
      field_weight,
    };

  static field_id lookup_field_id(const char *str);
  static const char *lookup_field_name(field_id id);

  struct field_name : public uncopyable
    {
      field_id id;
      const char *ptr;
      const std::string *str;

      // note, none of these copy their parameter, for speed.

      explicit field_name(field_id id);
      explicit field_name(const char *ptr);
      explicit field_name(const std::string &str);
    };

private:
  struct field
    {
      field_id id;
      std::string custom;
      std::string value;

      explicit field(const field_name &name);
      field(const field_name &name, const std::string &value);

      bool operator==(const field_name &name) const;
    };

  time_t _date;
  std::vector<field> _header;
  std::string _body;

public:
  activity();
  ~activity();

  bool read_file(const char *path);
  bool write_file(const char *path) const;
  bool make_filename(std::string &filename) const;

  time_t date() const;
  void set_date(time_t x);

  const std::string &body() const;
  std::string &body();
  void set_body(const std::string &x);

  bool has_field(field_id id) const;
  bool has_field(const field_name &name) const;

  std::string &field_value(const field_name &name);
  const std::string &field_value(const field_name &name) const;

  bool get_string_field(const field_name &name, const std::string **ptr) const;
  void set_string_field(const field_name &name, const std::string &x);

  bool get_distance_field(const field_name &name, double *ptr,
    distance_unit *unit_ptr = 0) const;
  void set_distance_field(const field_name &name, double x,
    distance_unit unit = unit_miles);

  bool get_duration_field(const field_name &name, double *ptr) const;
  void set_duration_field(const field_name &name, double x);

  bool get_pace_field(const field_name &name, double *ptr,
    pace_unit *unit_ptr = 0) const;
  void set_pace_field(const field_name &name, double x,
    pace_unit unit = unit_seconds_per_mile);

  bool get_speed_field(const field_name &name, double *ptr,
    speed_unit *unit_ptr = 0) const;
  void set_speed_field(const field_name &name, double x,
    speed_unit unit = unit_miles_per_hour);

  bool get_temperature_field(const field_name &name, double *ptr,
    temperature_unit *unit_ptr = 0) const;
  void set_temperature_field(const field_name &name, double x,
    temperature_unit unit = unit_celsius);

  bool get_keywords_field(const field_name &name,
    std::vector<std::string> *ptr) const;
  void set_keywords_field(const field_name &name,
    const std::vector<std::string> &x);

  bool get_fraction_field(const field_name &name, double *ptr) const;
  void set_fraction_field(const field_name &name, double x);

private:
  int field_index(const field_name &name) const;
};

// implementation details

inline
activity::field_name::field_name(field_id i)
: id(i), ptr(0)
{
}

inline
activity::field_name::field_name(const char *p)
: id(field_custom), ptr(p)
{
}

inline
activity::field_name::field_name(const std::string &s)
: id(field_custom), ptr(0), str(&s)
{
}

inline
activity::field::field(const field_name &n)
: id(n.id)
{
  if (id == field_custom)
    custom = n.ptr ? n.ptr : *n.str;
}

inline
activity::field::field(const field_name &n, const std::string &v)
: id(n.id),
  value(v)
{
  if (id == field_custom)
    custom = n.ptr ? n.ptr : *n.str;
}

inline time_t
activity::date() const
{
  return _date;
}

inline bool
activity::has_field(field_id id) const
{
  return has_field(field_name(id));
}

inline const std::string &
activity::field_value(const field_name &name) const
{
  return const_cast<activity *>(this)->field_value(name);
}

inline const std::string &
activity::body() const
{
  return _body;
}

inline std::string &
activity::body()
{
  return _body;
}

} // namespace act

#endif /* ACT_ACTIVITY_H */
