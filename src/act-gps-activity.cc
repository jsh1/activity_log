// -*- c-style: gnu -*-

#include "act-gps-activity.h"

#include "act-format.h"
#include "act-gps-fit-parser.h"
#include "act-gps-tcx-parser.h"
#include "act-util.h"

#include <math.h>

namespace act {
namespace gps {

activity::activity()
: _sport(sport_type::unknown),
  _time(0),
  _duration(0),
  _distance(0),
  _avg_speed(0),
  _max_speed(0),
  _calories(0),
  _avg_heart_rate(0),
  _max_heart_rate(0),
  _has_location(false),
  _has_speed(false),
  _has_heart_rate(false),
  _has_altitude(false)
{
}

bool
activity::read_file(const char *path)
{
  if (path_has_extension(path, "fit"))
    return read_fit_file(path);
  else if (path_has_extension(path, "tcx"))
    return read_tcx_file(path);
  else if (path_has_extension(path, "tcx.gz")
	   || path_has_extension(path, "tcx.Z"))
    return read_compressed_tcx_file(path, "/usr/bin/zcat");
  else if (path_has_extension(path, "tcx.bz2"))
    return read_compressed_tcx_file(path, "/usr/bin/bzcat");
  else
    return false;
}

bool
activity::read_fit_file(const char *path)
{
  FILE_ptr fh(fopen(path, "rb"));

  if (fh)
    {
      fit_parser parser(*this);
      parser.parse_file(fh.get());
      return !parser.had_error();
    }
  else
    return false;
}

bool
activity::read_tcx_file(const char *path)
{
  FILE_ptr fh(fopen(path, "r"));

  if (fh)
    {
      tcx_parser parser(*this);
      parser.parse_file(fh.get());
      return !parser.had_error();
    }
  else
    return false;
}

bool
activity::read_compressed_tcx_file(const char *path, const char *prog)
{
  const char *argv[] = {prog, path, nullptr};

  output_pipe pipe(prog, argv);
  if (!pipe.start())
    return false;

  FILE_ptr fh(pipe.open_output("r"));

  if (fh)
    {
      tcx_parser parser(*this);
      parser.parse_file(fh.get());

      return !parser.had_error() && pipe.finish();
    }
  else
    return false;
}

void
activity::update_summary()
{
  _time = 0;
  _duration = 0;
  _distance = 0;
  _avg_speed = 0;
  _max_speed = 0;
  _calories = 0;
  _avg_heart_rate = 0;
  _max_heart_rate = 0;

  if (laps().size() < 1)
    return;

  _time = laps()[0].time;

  for (const auto &it : laps())
    {
      _duration += it.duration;
      _distance += it.distance;
      _max_speed = fmax(_max_speed, it.max_speed);
      _calories += it.calories;
      _avg_heart_rate += it.avg_heart_rate * it.duration;
      _max_heart_rate = fmax(_max_heart_rate, it.max_heart_rate);
    }

  _avg_speed = _distance / _duration;
  _avg_heart_rate = _avg_heart_rate / _duration;
}

void
activity::print_summary(FILE *fh) const
{
  std::string tem;

  format_date_time(tem, (time_t) time());
  fprintf(fh, "Date: %s\n", tem.c_str());
  tem.clear();

  format_duration(tem, duration());
  fprintf(fh, "Duration: %s\n", tem.c_str());
  tem.clear();

  format_distance(tem, distance(), unit_type::miles);
  fprintf(fh, "Distance: %s\n", tem.c_str());
  tem.clear();

  format_pace(tem, avg_speed(), unit_type::seconds_per_mile);
  fprintf(fh, "Pace: %s\n", tem.c_str());
  tem.clear();

  format_pace(tem, max_speed(), unit_type::seconds_per_mile);
  fprintf(fh, "Max-Pace: %s\n", tem.c_str());
  tem.clear();

  if (avg_heart_rate() != 0)
    fprintf(fh, "Avg-HR: %d\n", (int) avg_heart_rate());
  if (max_heart_rate() != 0)
    fprintf(fh, "Max-HR: %d\n", (int) max_heart_rate());

  if (calories() != 0)
    fprintf(fh, "Calories: %g\n", calories());
}

void
activity::print_laps(FILE *fh) const
{
  if (laps().size() == 0)
    return;

  bool has_hr = avg_heart_rate() != 0;

  if (has_hr)
    {
      fprintf(fh, "    %-3s  %8s  %6s  %5s %5s  %3s %3s  %4s\n", "Lap", "Time",
	      "Dist.", "Pace", "Max", "HR", "Max",
	      "Cal.");
    }
  else
    {
      fprintf(fh, "    %-3s  %8s  %6s  %5s %5s  %4s\n", "Lap", "Time",
	      "Dist.", "Pace", "Max", "Cal.");
    }

  const double miles_per_meter = 0.000621371192;

  int lap_idx = 0;
  for (const auto &it : laps())
    {
      std::string dur;
      format_time(dur, it.duration, true, "");

      std::string pace, max_pace;
      format_time(pace, 1/(it.avg_speed * miles_per_meter), false, "");
      format_time(max_pace, 1/(it.max_speed * miles_per_meter), false, "");

      std::string avg_hr, max_hr;
      if (has_hr)
	{
	  format_number(avg_hr, it.avg_heart_rate);
	  format_number(max_hr, it.max_heart_rate);
	}

      std::string cal;
      if (it.calories != 0)
	format_number(cal, it.calories);

      if (has_hr)
	{
	  fprintf(fh, "    %-3d  %8s  %6.2f  %5s %5s  %3s %3s  %4s\n",
		  lap_idx + 1, dur.c_str(), it.distance * miles_per_meter,
		  pace.c_str(), max_pace.c_str(), avg_hr.c_str(),
		  max_hr.c_str(), cal.c_str());
	}
      else
	{
	  fprintf(fh, "    %-3d  %8s  %6.2f  %5s %5s  %4s\n",
		  lap_idx + 1, dur.c_str(), it.distance * miles_per_meter,
		  pace.c_str(), max_pace.c_str(), cal.c_str());
	}

      lap_idx++;
    }

  if (lap_idx > 0)
    fputc('\n', fh);
}

void
activity::get_range(double point:: *field, double &ret_min, double &ret_max,
		    double &ret_mean, double &ret_sdev) const
{
  double min = 0, max = 0, total = 0, total_sq = 0, samples = 0;

  for (size_t li = 0; li < laps().size(); li++)
    {
      const lap &l = laps()[li];

      for (size_t ti = 0; ti < l.track.size(); ti++)
	{
	  const point &p = l.track[ti];
	  double value = p.*field;

	  if (p.distance == 0 || !(value > 0))
	    continue;

	  if (samples == 0)
	    min = max = value;
	  else
	    {
	      min = std::min(min, value);
	      max = std::max(max, value);
	    }

	  total += value;
	  total_sq += value * value;
	  samples++;
	}
    }

  ret_min = min;
  ret_max = max;

  if (samples > 0)
    {
      double recip = 1 / samples;
      ret_mean = total * recip;
      ret_sdev = sqrt(total_sq * recip - ret_mean * ret_mean);
    }
  else
    ret_mean = 0, ret_sdev = 0;
}

void
activity::lap::update_region()
{
  /* FIXME: none of this correctly handles regions spanning the wrap point. */

  double min_lat = 0, min_long = 0, max_lat = 0, max_long = 0;
  bool first = true;

  for (size_t i = 0; i < track.size(); i++)
    {
      const point &p = track[i];

      if (p.location.latitude == 0 && p.location.longitude == 0)
	continue;

      if (first)
	{
	  min_lat = max_lat = p.location.latitude;
	  min_long = max_long = p.location.longitude;
	  first = false;
	}
      else
	{
	  min_lat = std::min(min_lat, p.location.latitude);
	  max_lat = std::max(max_lat, p.location.latitude);
	  min_long = std::min(min_long, p.location.longitude);
	  max_long = std::max(max_long, p.location.longitude);
	}
    }

  location cen = location((min_lat + max_lat)*.5, (min_long + max_long)*.5);
  location_size sz = location_size(max_lat - min_lat, max_long - min_long);
  this->region = location_region(cen, sz);
}

void
activity::update_region()
{
  double min_lat = 0, min_long = 0, max_lat = 0, max_long = 0;
  bool first = true;

  for (size_t i = 0; i < laps().size(); i++)
    {
      lap &l = laps()[i];

      l.update_region();

      if (l.region.size.latitude != 0 || l.region.size.longitude != 0)
	{
	  double lat0 = (l.region.center.latitude
			 - l.region.size.latitude * .5);
	  double long0 = (l.region.center.longitude
			  - l.region.size.longitude * .5);
	  double lat1 = lat0 + l.region.size.latitude;
	  double long1 = long0 + l.region.size.longitude;

	  if (first)
	    {
	      min_lat = lat0;
	      max_lat = lat1;
	      min_long = long0;
	      max_long = long1;
	      first = false;
	    }
	  else
	    {
	      min_lat = std::min(min_lat, lat0);
	      max_lat = std::max(max_lat, lat1);
	      min_long = std::min(min_long, long0);
	      max_long = std::max(max_long, long1);
	    }
	}
    }

  location cen = location((min_lat + max_lat)*.5, (min_long + max_long)*.5);
  location_size sz = location_size(max_lat - min_lat, max_long - min_long);
  _region = location_region(cen, sz);
}

void
activity::smooth(const activity &src, int width)
{
  _activity_id = src._activity_id;
  _sport = src._sport;
  _device = src._device;

  _time = src._time;
  _duration = src._duration;
  _distance = src._distance;
  _avg_speed = src._avg_speed;
  _max_speed = src._max_speed;
  _calories = src._calories;
  _avg_heart_rate = src._avg_heart_rate;
  _max_heart_rate = src._max_heart_rate;

  _has_location = src._has_location;
  _has_speed = src._has_speed;
  _has_heart_rate = src._has_heart_rate;
  _has_altitude = src._has_altitude;

  for (const auto &it : src.laps())
    {
      _laps.push_back(lap());
      lap &l = _laps.back();

      l.time = it.time;
      l.duration = it.duration;
      l.distance = it.distance;
      l.avg_speed = it.avg_speed;
      l.max_speed = it.max_speed;
      l.calories = it.calories;
      l.avg_heart_rate = it.avg_heart_rate;
      l.max_heart_rate = it.max_heart_rate;
      l.region = it.region;

      l.track.resize(it.track.size());
    }

  const_iterator s_in = src.begin();
  const_iterator s_out = s_in;
  iterator it = begin();

  point sum;
  int sum_n = 0;
  int i = 0;

  while (s_in != src.end())
    {
      if (i >= width)
	{
	  const point &p = *s_out;
	  if (p.distance != 0)
	    {
	      sum.altitude -= p.altitude;
	      sum.speed -= p.speed;
	      sum.heart_rate -= p.heart_rate;
	      sum_n--;
	    }
	  s_out++;
	}

      const point &s = *s_in;

      if (s.distance != 0)
	{
	  sum.altitude += s.altitude;
	  sum.speed += s.speed;
	  sum.heart_rate += s.heart_rate;
	  sum_n++;
	}

      point &d = *it;

      if (sum_n > 0)
	{
	  double mul = 1. / sum_n;
	  d.time = s.time;
	  d.location = s.location;
	  d.altitude = sum.altitude * mul;
	  d.distance = s.distance;
	  d.speed = sum.speed * mul;
	  d.heart_rate = sum.heart_rate * mul;
	}
      else
	d = s;

      i++;
      s_in++;
      it++;
    }
}

bool
activity::point_at_time(double t, point &ret_p) const
{
  for (const auto &lap : laps())
    {
      if (lap.time + lap.duration < t)
	continue;
      if (lap.time > t)
	return false;

      const activity::point *last_p = nullptr;

      for (const auto &pt : lap.track)
	{
	  if (pt.time == 0)
	    continue;

	  if (pt.time > t)
	    {
	      if (last_p != nullptr)
		{
		  double f = (pt.time - t) / (pt.time - last_p->time);
		  mix(ret_p, *last_p, pt, 1-f);
		  return true;
		}
	      else
		return false;
	    }
      
	  last_p = &pt;
	}
    }

  return false;
}

} // namespace gps


void
mix(gps::activity::point &a, const gps::activity::point &b,
  const gps::activity::point &c, double f)
{
  mix(a.time, b.time, c.time, f);
  mix(a.location, b.location, c.location, f);
  mix(a.altitude, b.altitude, c.altitude, f);
  mix(a.distance, b.distance, c.distance, f);
  mix(a.speed, b.speed, c.speed, f);
  mix(a.heart_rate, b.heart_rate, c.heart_rate, f);
}

} // namespace act
