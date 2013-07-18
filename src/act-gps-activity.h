// -*- c-style: gnu -*-

#ifndef ACT_GPS_ACTIVITY_H
#define ACT_GPS_ACTIVITY_H

#include "act-base.h"

#include <string>
#include <vector>

namespace act {
namespace gps {

class activity
{
public:
  enum sport_type
    {
      sport_unknown,
      sport_running,
      sport_cycling,
      sport_swimming,
    };

  class point
    {
      double _time;
      double _latitude;
      double _longitude;
      double _altitude;
      double _distance;
      double _speed;
      double _heart_rate;

    public:
      point()
      : _time(0), _latitude(0), _longitude(0), _altitude(0),
        _distance(0), _speed(0), _heart_rate(0) {}

      void set_time(double x) {_time = x;}
      double time() const {return _time;}

      void set_latitude(double x) {_latitude = x;}
      double latitude() const {return _latitude;}

      void set_longitude(double x) {_longitude = x;}
      double longitude() const {return _longitude;}

      void set_altitude(double x) {_altitude = x;}
      double altitude() const {return _altitude;}

      void set_distance(double x) {_distance = x;}
      double distance() const {return _distance;}

      void set_speed(double x) {_speed = x;}
      double speed() const {return _speed;}

      void set_heart_rate(double x) {_heart_rate = x;}
      double heart_rate() const {return _heart_rate;}
    };

  class lap
    {
      double _time;
      double _duration;
      double _distance;
      double _avg_speed;
      double _max_speed;
      double _calories;
      double _avg_heart_rate;
      double _max_heart_rate;
      std::vector<point> _track;

    public:
      lap()
      : _time(0), _duration(0), _distance(0), _avg_speed(0),
        _max_speed(0), _calories(0), _avg_heart_rate(0),
	_max_heart_rate(0) {}

      void set_time(double x) {_time = x;}
      double time() const {return _time;}

      void set_duration(double x) {_duration = x;}
      double duration() const {return _duration;}

      void set_distance(double x) {_distance = x;}
      double distance() const {return _distance;}

      void set_avg_speed(double x) {_avg_speed = x;}
      double avg_speed() const {return _avg_speed;}

      void set_max_speed(double x) {_max_speed = x;}
      double max_speed() const {return _max_speed;}

      void set_calories(double x) {_calories = x;}
      double calories() const {return _calories;}

      void set_avg_heart_rate(double x) {_avg_heart_rate = x;}
      double avg_heart_rate() const {return _avg_heart_rate;}

      void set_max_heart_rate(double x) {_max_heart_rate = x;}
      double max_heart_rate() const {return _max_heart_rate;}

      std::vector<point> &track() {return _track;}
      const std::vector<point> &track() const {return _track;}
    };

private:
  std::string _activity_id;
  sport_type _sport;
  std::string _device;

  double _time;
  double _duration;
  double _distance;
  double _avg_speed;
  double _max_speed;
  double _calories;
  double _avg_heart_rate;
  double _max_heart_rate;

  std::vector<lap> _laps;

public:
  activity();

  // uses file extension to deduce format
  bool read_file(const char *path);

  bool read_fit_file(const char *path);
  bool read_tcx_file(const char *path);

  void update_summary();

  void set_sport(sport_type x) {_sport = x;}
  sport_type sport() const {return _sport;}

  void set_activity_id(const std::string &s) {_activity_id = s;}
  const std::string &activity_id() const {return _activity_id;}

  void set_device(const std::string &s) {_device = s;}
  const std::string &device() const {return _device;}

  void set_time(double x) {_time = x;}
  double time() const {return _time;}

  void set_duration(double x) {_duration = x;}
  double duration() const {return _duration;}

  void set_distance(double x) {_distance = x;}
  double distance() const {return _distance;}

  void set_avg_speed(double x) {_avg_speed = x;}
  double avg_speed() const {return _avg_speed;}

  void set_max_speed(double x) {_max_speed = x;}
  double max_speed() const {return _max_speed;}

  void set_calories(double x) {_calories = x;}
  double calories() const {return _calories;}

  void set_avg_heart_rate(double x) {_avg_heart_rate = x;}
  double avg_heart_rate() const {return _avg_heart_rate;}

  void set_max_heart_rate(double x) {_max_heart_rate = x;}
  double max_heart_rate() const {return _max_heart_rate;}

  std::vector<lap> &laps() {return _laps;}
  const std::vector<lap> &laps() const {return _laps;}
};

} // namespace gps
} // namespace act

#endif /* ACT_GPS_ACTIVITY_H */
