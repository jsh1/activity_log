// -*- c-style: gnu -*-

#ifndef ACT_ACTIVITY_H
#define ACT_ACTIVITY_H

#include "act-activity-storage.h"

#include "act-types.h"
#include "act-gps-activity.h"

#include <memory>

namespace act {

class activity
{
public:
  activity(std::shared_ptr<activity_storage> storage);

  std::shared_ptr<activity_storage> storage();
  std::shared_ptr<const activity_storage> storage() const;

  void invalidate_cached_values();

  bool make_filename(std::string &filename) const;

  void printf(const char *format) const;

  const std::string &body() const;
  std::string &body();

  std::string &operator[] (const char *name);
  std::string &operator[] (const std::string &name);
  const std::string *field_ptr (const char *name) const;
  const std::string *field_ptr (const std::string &name) const;

  double field_value(field_id id) const;
  const std::vector<std::string> *field_keywords_ptr(field_id id) const;
  unit_type field_unit(field_id id) const;

  const gps::activity *gps_data() const;

  time_t date() const;
  double duration() const;

  double distance() const;
  unit_type distance_unit() const;

  double speed() const;
  unit_type speed_unit() const;

  double max_speed() const;
  unit_type max_speed_unit() const;

  double effort() const;
  double quality() const;

  double resting_hr() const;
  double average_hr() const;
  double max_hr() const;

  double calories() const;

  double weight() const;
  unit_type weight_unit() const;

  const std::vector<std::string> &equipment() const;

  double temperature() const;
  unit_type temperature_unit() const;

  const std::vector<std::string> &weather() const;

  const std::vector<std::string> &keywords() const;

private:
  std::shared_ptr<activity_storage> _storage;

  mutable std::unique_ptr<gps::activity> _gps_data;

  // Split the properties into groups, helps avoid parsing the GPS
  // file until we really need it.

  enum field_groups
    {
      group_timing = 1U << 0,
      group_physiological = 1U << 1,
      group_other = 1U << 2,
      group_all = 0xffU,
    };

  // group_timing

  mutable time_t _date;
  mutable double _duration;
  mutable double _distance;
  mutable unit_type _distance_unit;
  mutable double _speed;
  mutable unit_type _speed_unit;
  mutable double _max_speed;
  mutable unit_type _max_speed_unit;

  // group_physiological

  mutable double _resting_hr;
  mutable double _average_hr;
  mutable double _max_hr;
  mutable double _calories;
  mutable double _weight;
  mutable unit_type _weight_unit;

  // rest is group_other

  mutable double _effort;
  mutable double _quality;
  mutable double _temperature;
  mutable unit_type _temperature_unit;

  mutable std::vector<std::string> _equipment;
  mutable std::vector<std::string> _weather;
  mutable std::vector<std::string> _keywords;

  mutable unsigned int _invalid_groups;

  void validate_cached_values(unsigned int groups) const;
  void read_cached_values(unsigned int groups) const;

  void print_expansion(FILE *fh, const char *name, const char *arg) const;
  void print_field(FILE *fh, const char *name, const char *arg) const;
};

// implementation details

inline std::shared_ptr<activity_storage>
activity::storage()
{
  return _storage;
}

inline std::shared_ptr<const activity_storage>
activity::storage() const
{
  return _storage;
}

inline const std::string &
activity::body() const
{
  return _storage->body();
}

inline std::string &
activity::body()
{
  return _storage->body();
}

inline std::string &
activity::operator[] (const char *name)
{
  return (*_storage)[name];
}

inline std::string &
activity::operator[] (const std::string &name)
{
  return (*_storage)[name];
}

inline const std::string *
activity::field_ptr(const char *name) const
{
  return _storage->field_ptr(name);
}

inline const std::string *
activity::field_ptr(const std::string &name) const
{
  return _storage->field_ptr(name);
}

inline void
activity::invalidate_cached_values()
{
  _invalid_groups = group_all;
}

inline void
activity::validate_cached_values(unsigned int groups) const
{
  if (_invalid_groups & groups)
    read_cached_values(groups);
}

} // namespace act

#endif /* ACT_ACTIVITY_H */
