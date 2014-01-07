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

#ifndef ACT_GPS_ACTIVITY_H
#define ACT_GPS_ACTIVITY_H

#include "act-types.h"

#include <string>
#include <vector>

namespace act {
namespace gps {

class activity
{
public:
  enum class sport_type
    {
      unknown,
      running,
      cycling,
      swimming,
    };

  enum class point_field
    {
      timestamp,
      altitude,
      distance,
      speed,
      pace,
      heart_rate,
      cadence,
      vertical_oscillation,
      stance_time,
      stance_ratio,
      stride_length,
      efficiency,
    };

  struct point
    {
      double timestamp;
      location location;
      float altitude;
      float distance;
      float speed;
      float heart_rate;
      float cadence;
      float vertical_oscillation;
      float stance_time;		/* aka ground contact time */
      float stance_ratio;

      point()
      : timestamp(0), altitude(0), distance(0), speed(0), heart_rate(0),
        cadence(0), vertical_oscillation(0), stance_time(0),
	stance_ratio(0) {}

      typedef double (*field_fn)(const point *);

      static field_fn field_function(point_field field);

      void add(const point &x);
      void sub(const point &x);
      void mul(float x);
    };

  struct lap
    {
      double start_time;
      float total_elapsed_time;
      float total_duration;
      float total_distance;
      float total_ascent;
      float total_descent;
      float total_calories;
      float avg_speed;
      float max_speed;
      float avg_heart_rate;
      float max_heart_rate;
      float avg_cadence;
      float max_cadence;
      float avg_vertical_oscillation;
      float avg_stance_time;
      float avg_stance_ratio;
      std::vector<point> track;
      location_region region;

      lap()
      : start_time(0), total_elapsed_time(0), total_duration(0),
	total_distance(0), total_ascent(0), total_descent(0),
	total_calories(0), avg_speed(0), max_speed(0), avg_heart_rate(0),
	max_heart_rate(0), avg_cadence(0), max_cadence(0),
	avg_vertical_oscillation(0), avg_stance_time(0),
	avg_stance_ratio(0) {}

      void update_region();
    };

  class iterator
    {
      activity *activity;
      size_t lap;
      size_t point;

    public:
      iterator(class activity &a, bool end);
      iterator(const iterator &rhs);
      iterator &operator=(const iterator &rhs);
      iterator &operator++();
      iterator operator++(int);
      bool operator==(const iterator &rhs) const;
      bool operator!=(const iterator &rhs) const;
      struct point &operator*() const;
      struct point *operator->() const;
    };

  class const_iterator
    {
      const activity *activity;
      size_t lap;
      size_t point;

    public:
      const_iterator(const class activity &a, bool end);
      const_iterator(const const_iterator &rhs);
      const_iterator &operator=(const const_iterator &rhs);
      const_iterator &operator++();
      const_iterator operator++(int);
      bool operator==(const const_iterator &rhs) const;
      bool operator!=(const const_iterator &rhs) const;
      const struct point &operator*() const;
      const struct point *operator->() const;
    };

private:
  std::string _activity_id;
  sport_type _sport;
  std::string _device;

  double _start_time;
  float _total_elapsed_time;
  float _total_duration;
  float _total_distance;
  float _training_effect;
  float _total_ascent;
  float _total_descent;
  float _total_calories;
  float _avg_speed;
  float _max_speed;
  float _avg_heart_rate;
  float _max_heart_rate;
  float _avg_cadence;
  float _max_cadence;
  float _avg_vertical_oscillation;
  float _avg_stance_time;
  float _avg_stance_ratio;

  std::vector<lap> _laps;

  location_region _region;

  bool _has_location;
  bool _has_speed;
  bool _has_heart_rate;
  bool _has_cadence;
  bool _has_altitude;
  bool _has_dynamics;

public:
  activity();

  // iterates over all points, ignoring lap boundaries

  iterator begin();
  iterator end();
  const_iterator begin() const;
  const_iterator end() const;
  const_iterator cbegin() const;
  const_iterator cend() const;

  // uses file extension to deduce format
  bool read_file(const char *path);

  bool read_fit_file(const char *path);
  bool read_tcx_file(const char *path);
  bool read_compressed_tcx_file(const char *file_path, const char *prog_path);

  void update_summary();

  void print_summary(FILE *fh) const;
  void print_laps(FILE *fh) const;

  void get_range(point_field field, double &ret_min,
    double &ret_max, double &ret_mean, double &ret_sdev) const;

  void set_sport(sport_type x) {_sport = x;}
  sport_type sport() const {return _sport;}

  void set_activity_id(const std::string &s) {_activity_id = s;}
  const std::string &activity_id() const {return _activity_id;}

  void set_device(const std::string &s) {_device = s;}
  const std::string &device() const {return _device;}

  void set_start_time(double x) {_start_time = x;}
  double start_time() const {return _start_time;}

  void set_total_elapsed_time(float x) {_total_elapsed_time = x;}
  float total_elapsed_time() const {return _total_elapsed_time;}

  void set_total_duration(float x) {_total_duration = x;}
  float total_duration() const {return _total_duration;}

  void set_total_distance(float x) {_total_distance = x;}
  float total_distance() const {return _total_distance;}

  void set_training_effect(float x) {_training_effect = x;}
  float training_effect() const {return _training_effect;}

  void set_total_ascent(float x) {_total_ascent = x;}
  float total_ascent() const {return _total_ascent;}

  void set_total_descent(float x) {_total_descent = x;}
  float total_descent() const {return _total_descent;}

  void set_total_calories(float x) {_total_calories = x;}
  float total_calories() const {return _total_calories;}

  void set_avg_speed(float x) {_avg_speed = x;}
  float avg_speed() const {return _avg_speed;}

  void set_max_speed(float x) {_max_speed = x;}
  float max_speed() const {return _max_speed;}

  void set_avg_heart_rate(float x) {_avg_heart_rate = x;}
  float avg_heart_rate() const {return _avg_heart_rate;}

  void set_max_heart_rate(float x) {_max_heart_rate = x;}
  float max_heart_rate() const {return _max_heart_rate;}

  void set_avg_cadence(float x) {_avg_cadence = x;}
  float avg_cadence() const {return _avg_cadence;}

  void set_max_cadence(float x) {_max_cadence = x;}
  float max_cadence() const {return _max_cadence;}

  void set_avg_vertical_oscillation(float x) {_avg_vertical_oscillation = x;}
  float avg_vertical_oscillation() const {return _avg_vertical_oscillation;}

  void set_avg_stance_time(float x) {_avg_stance_time = x;}
  float avg_stance_time() const {return _avg_stance_time;}

  void set_avg_stance_ratio(float x) {_avg_stance_ratio = x;}
  float avg_stance_ratio() const {return _avg_stance_ratio;}

  std::vector<lap> &laps() {return _laps;}
  const std::vector<lap> &laps() const {return _laps;}

  const location_region &region() const {return _region;}

  void set_has_location(bool x) {_has_location = x;}
  bool has_location() const {return _has_location;}

  void set_has_speed(bool x) {_has_speed = x;}
  bool has_speed() const {return _has_speed;}

  void set_has_heart_rate(bool x) {_has_heart_rate = x;}
  bool has_heart_rate() const {return _has_heart_rate;}

  void set_has_altitude(bool x) {_has_altitude = x;}
  bool has_altitude() const {return _has_altitude;}

  void set_has_cadence(bool x) {_has_cadence = x;}
  bool has_cadence() const {return _has_cadence;}

  void set_has_dynamics(bool x) {_has_dynamics = x;}
  bool has_dynamics() const {return _has_dynamics;}

  void update_region();

  void smooth(const activity &src, int width);

  bool point_at_time(double t, point &ret_p) const;
};

// implementation details

inline
activity::iterator::iterator(class activity &a, bool end)
: activity(&a), lap(!end ? 0 : a.laps().size()), point(0)
{
}

inline
activity::iterator::iterator(const iterator &rhs)
: activity(rhs.activity), lap(rhs.lap), point(rhs.point)
{
}

inline activity::iterator &
activity::iterator::operator=(const iterator &rhs)
{
  activity = rhs.activity;
  lap = rhs.lap;
  point = rhs.point;
  return *this;
}

inline activity::iterator &
activity::iterator::operator++()
{
  ++point;
  if (point >= activity->laps()[lap].track.size())
    lap++, point = 0;
  return *this;
}

inline activity::iterator
activity::iterator::operator++(int)
{
  iterator ret = *this;
  ++(*this);
  return ret;
}

inline bool
activity::iterator::operator==(const iterator &rhs) const
{
  return activity == rhs.activity && lap == rhs.lap && point == rhs.point;
}

inline bool
activity::iterator::operator!=(const iterator &rhs) const
{
  return !(activity == rhs.activity && lap == rhs.lap && point == rhs.point);
}

inline activity::point &
activity::iterator::operator*() const
{
#if DEBUG
  assert(lap < activity->laps().size()
	 && point < activity->laps()[lap].track.size());
#endif
  return activity->laps()[lap].track[point];
}

inline activity::point *
activity::iterator::operator->() const
{
#if DEBUG
  assert(lap < activity->laps().size()
	 && point < activity->laps()[lap].track.size());
#endif
  return &activity->laps()[lap].track[point];
}

inline
activity::const_iterator::const_iterator(const class activity &a, bool end)
: activity(&a), lap(!end ? 0 : a.laps().size()), point(0)
{
}

inline
activity::const_iterator::const_iterator(const const_iterator &rhs)
: activity(rhs.activity), lap(rhs.lap), point(rhs.point)
{
}

inline activity::const_iterator &
activity::const_iterator::operator=(const const_iterator &rhs)
{
  activity = rhs.activity;
  lap = rhs.lap;
  point = rhs.point;
  return *this;
}

inline activity::const_iterator &
activity::const_iterator::operator++()
{
  ++point;
  if (point >= activity->laps()[lap].track.size())
    lap++, point = 0;
  return *this;
}

inline activity::const_iterator
activity::const_iterator::operator++(int)
{
  const_iterator ret = *this;
  ++(*this);
  return ret;
}

inline bool
activity::const_iterator::operator==(const const_iterator &rhs) const
{
  return activity == rhs.activity && lap == rhs.lap && point == rhs.point;
}

inline bool
activity::const_iterator::operator!=(const const_iterator &rhs) const
{
  return !(activity == rhs.activity && lap == rhs.lap && point == rhs.point);
}

inline const activity::point &
activity::const_iterator::operator*() const
{
#if DEBUG
  assert(lap < activity->laps().size()
	 && point < activity->laps()[lap].track.size());
#endif
  return activity->laps()[lap].track[point];
}

inline const activity::point *
activity::const_iterator::operator->() const
{
#if DEBUG
  assert(lap < activity->laps().size()
	 && point < activity->laps()[lap].track.size());
#endif
  return &activity->laps()[lap].track[point];
}

inline activity::iterator
activity::begin()
{
  return iterator(*this, false);
}

inline activity::iterator
activity::end()
{
  return iterator(*this, true);
}

inline activity::const_iterator
activity::begin() const
{
  return const_iterator(*this, false);
}

inline activity::const_iterator
activity::end() const
{
  return const_iterator(*this, true);
}

inline activity::const_iterator
activity::cbegin() const
{
  return begin();
}

inline activity::const_iterator
activity::cend() const
{
  return end();
}

} // namespace gps

void mix(gps::activity::point &a, const gps::activity::point &b,
  const gps::activity::point &c, float f);

} // namespace act

#endif /* ACT_GPS_ACTIVITY_H */
