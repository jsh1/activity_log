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
  _start_time(0),
  _total_elapsed_time(0),
  _total_duration(0),
  _total_distance(0),
  _training_effect(0),
  _total_ascent(0),
  _total_descent(0),
  _total_calories(0),
  _avg_speed(0),
  _max_speed(0),
  _avg_heart_rate(0),
  _max_heart_rate(0),
  _avg_cadence(0),
  _max_cadence(0),
  _avg_vertical_oscillation(0),
  _avg_stance_time(0),
  _avg_stance_ratio(0),
  _has_location(false),
  _has_speed(false),
  _has_heart_rate(false),
  _has_cadence(false),
  _has_altitude(false),
  _has_dynamics(false)
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
  _start_time = 0;
  _total_elapsed_time = 0;
  _total_duration = 0;
  _total_distance = 0;
  _total_ascent = 0;
  _total_descent = 0;
  _total_calories = 0;
  _avg_speed = 0;
  _max_speed = 0;
  _avg_heart_rate = 0;
  _max_heart_rate = 0;
  _avg_cadence = 0;
  _max_cadence = 0;
  _avg_vertical_oscillation = 0;
  _avg_stance_time = 0;
  _avg_stance_ratio = 0;

  if (laps().size() < 1)
    return;

  _start_time = laps()[0].start_time;

  for (auto &it : laps())
    {
      if (it.total_elapsed_time == 0 && it.track.size() >= 2)
	{
	  it.total_elapsed_time = (it.track.back().timestamp
				   - it.track.front().timestamp);
	}

      _total_elapsed_time += it.total_elapsed_time;
      _total_duration += it.total_duration;
      _total_distance += it.total_distance;
      _total_ascent += it.total_ascent;
      _total_descent += it.total_descent;
      _total_calories += it.total_calories;
      _max_speed = fmax(_max_speed, it.max_speed);
      _avg_heart_rate += it.avg_heart_rate * it.total_duration;
      _max_heart_rate = fmax(_max_heart_rate, it.max_heart_rate);
      _avg_cadence += it.avg_cadence * it.total_duration;
      _max_cadence = fmax(_max_cadence, it.max_cadence);
      _avg_vertical_oscillation += it.avg_vertical_oscillation * it.total_duration;
      _avg_stance_time += it.avg_stance_time * it.total_duration;
      _avg_stance_ratio += it.avg_stance_ratio * it.total_duration;
    }

  _avg_speed = _total_distance / _total_duration;
  _avg_heart_rate = _avg_heart_rate / _total_duration;
  _avg_cadence = _avg_cadence / _total_duration;
  _avg_vertical_oscillation = _avg_vertical_oscillation / _total_duration;
  _avg_stance_time = _avg_stance_time / _total_duration;
  _avg_stance_ratio = _avg_stance_ratio / _total_duration;
}

void
activity::print_summary(FILE *fh) const
{
  std::string tem;

  format_date_time(tem, (time_t) start_time());
  fprintf(fh, "Date: %s\n", tem.c_str());
  tem.clear();

  format_duration(tem, total_duration());
  fprintf(fh, "Duration: %s\n", tem.c_str());
  tem.clear();

  format_duration(tem, total_elapsed_time());
  fprintf(fh, "Elapsed Time: %s\n", tem.c_str());
  tem.clear();

  format_distance(tem, total_distance(), unit_type::miles);
  fprintf(fh, "Distance: %s\n", tem.c_str());
  tem.clear();

  if (training_effect() != 0)
    fprintf(fh, "Training Effect: %.1f\n", training_effect());

  format_distance(tem, total_ascent(), unit_type::feet);
  fprintf(fh, "Ascent: %s\n", tem.c_str());
  tem.clear();

  format_distance(tem, total_descent(), unit_type::feet);
  fprintf(fh, "Descent: %s\n", tem.c_str());
  tem.clear();

  format_pace(tem, avg_speed(), unit_type::seconds_per_mile);
  fprintf(fh, "Pace: %s\n", tem.c_str());
  tem.clear();

  format_pace(tem, max_speed(), unit_type::seconds_per_mile);
  fprintf(fh, "Max-Pace: %s\n", tem.c_str());
  tem.clear();

  if (has_heart_rate())
    {
      format_heart_rate(tem, avg_heart_rate(), unit_type::beats_per_minute);
      fprintf(fh, "Avg-HR: %s\n", tem.c_str());
      tem.clear();

      format_heart_rate(tem, max_heart_rate(), unit_type::beats_per_minute);
      fprintf(fh, "Max-HR: %s\n", tem.c_str());
      tem.clear();
    }

  if (has_cadence())
    {
      format_cadence(tem, avg_cadence(), unit_type::steps_per_minute);
      fprintf(fh, "Avg-Cadence: %s\n", tem.c_str());
      tem.clear();

      format_cadence(tem, max_cadence(), unit_type::steps_per_minute);
      fprintf(fh, "Max-Cadence: %s\n", tem.c_str());
      tem.clear();
    }

  if (has_dynamics())
    {
      format_distance(tem, avg_vertical_oscillation(), unit_type::millimetres);
      fprintf(fh, "Avg-Vertical-Oscillation: %s\n", tem.c_str());
      tem.clear();

      format_duration(tem, avg_stance_time());
      fprintf(fh, "Avg-Stance-Time: %s\n", tem.c_str());
      tem.clear();

      fprintf(fh, "Avg-Stance-Ratio: %.1f%%\n",
	      avg_stance_ratio() * 100);
    }

  if (total_calories() != 0)
    fprintf(fh, "Calories: %g\n", total_calories());
}

void
activity::print_laps(FILE *fh) const
{
  if (laps().size() == 0)
    return;

  fprintf(fh, "    %-3s  %8s  %6s  %5s %5s", "Lap", "Time", "Dist.",
	  "Pace", "Max");

  if (has_heart_rate())
    fprintf(fh, "  %3s %3s", "HR", "Max");
  if (has_cadence())
    fprintf(fh, "  %6s %6s", "Avg Cad", "Max Cad");
  if (has_dynamics())
    fprintf(fh, "  %4s  %3s", "Osc", "GCT");

  fprintf(fh, "  %4s\n", "Cal.");

  const double miles_per_meter = 0.000621371192;

  int lap_idx = 0;
  for (const auto &it : laps())
    {
      std::string dur;
      format_time(dur, it.total_duration, true, "");

      std::string pace, max_pace;
      format_time(pace, 1/(it.avg_speed * miles_per_meter), false, "");
      format_time(max_pace, 1/(it.max_speed * miles_per_meter), false, "");

      fprintf(fh, "    %-3d  %8s  %6.2f  %5s %5s", lap_idx + 1, dur.c_str(),
	      it.total_distance * miles_per_meter, pace.c_str(),
	      max_pace.c_str());

      if (has_heart_rate())
	{
	  std::string avg_str, max_str;
	  format_number(avg_str, it.avg_heart_rate);
	  format_number(max_str, it.max_heart_rate);

	  fprintf(fh, "  %3s %3s", avg_str.c_str(), max_str.c_str());
	}

      if (has_cadence())
	{
	  std::string avg_str, max_str;
	  format_number(avg_str, round(it.avg_cadence*10)*.1);
	  format_number(max_str, round(it.max_cadence*10)*.1);

	  fprintf(fh, "  %6s %6s", avg_str.c_str(), max_str.c_str());
	}

      if (has_dynamics())
	{
	  char buf[20];
	  snprintf(buf, sizeof(buf), "%.1f", it.avg_vertical_oscillation * 100);
	  fprintf(fh, "  %4s  %3d %.1f", buf, (int)(it.avg_stance_time * 1000),
		  it.avg_stance_ratio * 100);
	}

      std::string cal;
      if (it.total_calories != 0)
	format_number(cal, it.total_calories);

      fputc('\n', fh);
      lap_idx++;
    }

  if (lap_idx > 0)
    fputc('\n', fh);
}

activity::point::field_fn
activity::point::field_function(point_field field)
{
  switch (field)
    {
    case point_field::timestamp:
      return [] (const point *p) -> double {return p->timestamp;};

    case point_field::altitude:
      return [] (const point *p) -> double {return p->altitude;};

    case point_field::distance:
      return [] (const point *p) -> double {return p->distance;};

    case point_field::speed:
      return [] (const point *p) -> double {return p->speed;};

    case point_field::pace:
      return [] (const point *p) -> double {return 1 / p->speed;};

    case point_field::heart_rate:
      return [] (const point *p) -> double {return p->heart_rate;};

    case point_field::cadence:
      return [] (const point *p) -> double {return p->cadence;};

    case point_field::vertical_oscillation:
      return [] (const point *p) -> double {return p->vertical_oscillation;};

    case point_field::stance_time:
      return [] (const point *p) -> double {return p->stance_time;};

    case point_field::stance_ratio:
      return [] (const point *p) -> double {return p->stance_ratio;};

    case point_field::stride_length:
      return [] (const point *p) -> double {
	return p->cadence != 0 ? p->speed / (p->cadence * (1/60.)) : 0;};

    case point_field::efficiency:
      return [] (const point *p) -> double {
	return p->speed != 0 ? (p->heart_rate * (1/60.)) / p->speed : 0;};

    default:
      return nullptr;
    }
}

void
activity::point::add(const point &x)
{
  timestamp += x.timestamp;
  location.latitude += x.location.latitude;
  location.longitude += x.location.longitude;
  altitude += x.altitude;
  distance += x.distance;
  speed += x.speed;
  heart_rate += x.heart_rate;
  cadence += x.cadence;
  vertical_oscillation += x.vertical_oscillation;
  stance_time += x.stance_time;
  stance_ratio += x.stance_ratio;
}

void
activity::point::sub(const point &x)
{
  timestamp -= x.timestamp;
  location.latitude -= x.location.latitude;
  location.longitude -= x.location.longitude;
  altitude -= x.altitude;
  distance -= x.distance;
  speed -= x.speed;
  heart_rate -= x.heart_rate;
  cadence -= x.cadence;
  vertical_oscillation -= x.vertical_oscillation;
  stance_time -= x.stance_time;
  stance_ratio -= x.stance_ratio;
}

void
activity::point::mul(float x)
{
  timestamp *= x;
  location.latitude *= x;
  location.longitude *= x;
  altitude *= x;
  distance *= x;
  speed *= x;
  heart_rate *= x;
  cadence *= x;
  vertical_oscillation *= x;
  stance_time *= x;
  stance_ratio *= x;
}

void
activity::get_range(point_field field, double &ret_min, double &ret_max,
		    double &ret_mean, double &ret_sdev) const
{
  double min = 0, max = 0, total = 0, total_sq = 0, samples = 0;

  point::field_fn field_fn = point::field_function(field);

  for (size_t li = 0; li < laps().size(); li++)
    {
      const lap &l = laps()[li];

      for (size_t ti = 0; ti < l.track.size(); ti++)
	{
	  const point &p = l.track[ti];
	  double value = field_fn(&p);

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

  _start_time = src._start_time;
  _total_elapsed_time = src._total_elapsed_time;
  _total_duration = src._total_duration;
  _total_distance = src._total_distance;
  _training_effect = src._training_effect;
  _total_ascent = src._total_ascent;
  _total_descent = src._total_descent;
  _total_calories = src._total_calories;
  _avg_speed = src._avg_speed;
  _max_speed = src._max_speed;
  _avg_heart_rate = src._avg_heart_rate;
  _max_heart_rate = src._max_heart_rate;
  _avg_cadence = src._avg_cadence;
  _max_cadence = src._max_cadence;

  _has_location = src._has_location;
  _has_speed = src._has_speed;
  _has_heart_rate = src._has_heart_rate;
  _has_cadence = src._has_cadence;
  _has_altitude = src._has_altitude;
  _has_dynamics = src._has_dynamics;

  for (const auto &it : src.laps())
    {
      _laps.push_back(lap());
      lap &l = _laps.back();

      l.start_time = it.start_time;
      l.total_elapsed_time = it.total_elapsed_time;
      l.total_duration = it.total_duration;
      l.total_distance = it.total_distance;
      l.total_ascent = it.total_ascent;
      l.total_descent = it.total_descent;
      l.total_calories = it.total_calories;
      l.avg_speed = it.avg_speed;
      l.max_speed = it.max_speed;
      l.avg_heart_rate = it.avg_heart_rate;
      l.max_heart_rate = it.max_heart_rate;
      l.avg_cadence = it.avg_cadence;
      l.max_cadence = it.max_cadence;
      l.avg_vertical_oscillation = it.avg_vertical_oscillation;
      l.avg_stance_time = it.avg_stance_time;
      l.avg_stance_ratio = it.avg_stance_ratio;
      l.region = it.region;

      l.track.resize(it.track.size());
    }

  const_iterator s_in = src.begin();
  const_iterator s_out = s_in;
  iterator it = begin();

  point sum;
  int sum_n = 0;
  int i = 0;

  /* FIXME: this doesn't handle non-uniform sample intervals. Normalize
     to a stream of 1s intervals by holding previous samples as we process
     the array? */

  while (s_in != src.end())
    {
      if (i >= width)
	{
	  const point &p = *s_out;
	  if (p.distance != 0)
	    {
	      sum.sub(p);
	      sum_n--;
	    }
	  s_out++;
	}

      const point &s = *s_in;

      if (s.distance != 0)
	{
	  sum.add(s);
	  sum_n++;
	}

      point &d = *it;

      if (sum_n > 0)
	{
	  d = sum;
	  d.mul(1. / sum_n);
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
      if (lap.start_time + lap.total_elapsed_time < t)
	continue;
      if (lap.start_time > t)
	return false;

      const activity::point *last_p = nullptr;

      for (const auto &pt : lap.track)
	{
	  if (pt.timestamp == 0)
	    continue;

	  if (pt.timestamp > t)
	    {
	      if (last_p != nullptr)
		{
		  float f = (pt.timestamp - t) / (pt.timestamp - last_p->timestamp);
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
  const gps::activity::point &c, float f)
{
  mix(a.timestamp, b.timestamp, c.timestamp, f);
  mix(a.location, b.location, c.location, f);
  mix(a.altitude, b.altitude, c.altitude, f);
  mix(a.distance, b.distance, c.distance, f);
  mix(a.speed, b.speed, c.speed, f);
  mix(a.heart_rate, b.heart_rate, c.heart_rate, f);
  mix(a.cadence, b.cadence, c.cadence, f);
  mix(a.vertical_oscillation, b.vertical_oscillation,
      c.vertical_oscillation, f);
  mix(a.stance_time, b.stance_time, c.stance_time, f);
  mix(a.stance_ratio, b.stance_ratio, c.stance_ratio, f);
}

} // namespace act
