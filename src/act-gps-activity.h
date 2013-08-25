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
  enum class sport_type
    {
      unknown,
      running,
      cycling,
      swimming,
    };

  struct point
    {
      double time;
      double latitude;
      double longitude;
      double altitude;
      double distance;
      double speed;
      double heart_rate;

      point()
      : time(0), latitude(0), longitude(0), altitude(0),
        distance(0), speed(0), heart_rate(0) {}
    };

  struct lap
    {
      double time;
      double duration;
      double distance;
      double avg_speed;
      double max_speed;
      double calories;
      double avg_heart_rate;
      double max_heart_rate;
      std::vector<point> track;

      lap()
      : time(0), duration(0), distance(0), avg_speed(0),
        max_speed(0), calories(0), avg_heart_rate(0),
	max_heart_rate(0) {}
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

  bool _has_location;
  bool _has_speed;
  bool _has_heart_rate;
  bool _has_altitude;

public:
  activity();

  // uses file extension to deduce format
  bool read_file(const char *path);

  bool read_fit_file(const char *path);
  bool read_tcx_file(const char *path);

  void update_summary();

  void print_summary(FILE *fh) const;
  void print_laps(FILE *fh) const;

  void get_range(double point:: *field, double &ret_min,
    double &ret_max, double &ret_mean, double &ret_sdev) const;

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

  void set_has_location(bool x) {_has_location = x;}
  bool has_location() const {return _has_location;}

  void set_has_speed(bool x) {_has_speed = x;}
  bool has_speed() const {return _has_speed;}

  void set_has_heart_rate(bool x) {_has_heart_rate = x;}
  bool has_heart_rate() const {return _has_heart_rate;}

  void set_has_altitude(bool x) {_has_altitude = x;}
  bool has_altitude() const {return _has_altitude;}
};

} // namespace gps
} // namespace act

#endif /* ACT_GPS_ACTIVITY_H */
