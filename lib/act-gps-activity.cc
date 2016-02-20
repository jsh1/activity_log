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

#include <float.h>
#include <math.h>

namespace act {
namespace gps {

activity::activity()
: _sport(sport_type::unknown),
  _has_location(false),
  _has_distance(false),
  _has_speed(false),
  _has_heart_rate(false),
  _has_cadence(false),
  _has_altitude(false),
  _has_dynamics(false),
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
  _recovery_heart_rate(0),
  _recovery_heart_rate_timestamp(0),
  _avg_cadence(0),
  _max_cadence(0),
  _avg_vertical_oscillation(0),
  _avg_stance_time(0),
  _avg_stance_ratio(0)
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
activity::update_points()
{
  // We used to only generate per-point speed values if !has_speed(),
  // but some devices overly smooth their reported speed values, so we
  // now rebuild the speed values every time. Distance values don't
  // appear to be smoothed so (for now) we'll use the original data if
  // it exists.

  if (has_location() && !has_distance())
    {
      point *last_p = nullptr;

      double total_distance = 0;

      for (auto &p : _points)
	{
	  if (p.location.is_valid())
	    {
	      if (last_p != nullptr
		  && last_p->location.is_valid()
		  && p.elapsed_time - last_p->elapsed_time > 1e-3f
		  && p.follows_continuously(*last_p))
		{
		  total_distance += p.location.distance(last_p->location);
		}

	      last_p = &p;
	    }
	  else
	    last_p = nullptr;

	  p.distance = total_distance;
	}

      set_has_distance(true);
    }

  if (has_distance())
    {
      point *last_p = nullptr;

      for (auto &p : _points)
	{
	  if (p.distance != 0)
	    {
	      if (last_p != nullptr
		  && p.follows_continuously(*last_p))
		{
		  float t_delta = p.elapsed_time - last_p->elapsed_time;
		  if (t_delta > 1e-3f)
		    {
		      p.speed = (p.distance - last_p->distance) / t_delta;
		      if (last_p->speed == 0 && last_p->distance != 0)
			last_p->speed = p.speed;
		    }
		  else
		    p.speed = last_p->speed;
		}

	      last_p = &p;
	    }
	  else
	    last_p = nullptr;
	}

      set_has_speed(true);
    }
}

void
activity::update_regions()
{
  /* FIXME: none of this correctly handles regions spanning the wrap point. */

  double min_lat = 0, min_long = 0, max_lat = 0, max_long = 0;
  bool first = true;

  auto lap = _laps.begin();

  double lap_min_lat = 0, lap_min_long = 0, lap_max_lat = 0, lap_max_long = 0;
  bool lap_first = true;

  for (const auto &p : _points)
    {
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

      if (lap != _laps.end()
	  && p.elapsed_time > (lap->start_elapsed_time
			       + lap->total_elapsed_time))
	{
	  location cen = location((min_lat + max_lat)*.5,
				  (min_long + max_long)*.5);
	  location_size sz = location_size(max_lat - min_lat,
					   max_long - min_long);
	  lap->region = location_region(cen, sz);
	  lap_min_lat = lap_max_lat = 0;
	  lap_min_long = lap_max_long = 0;
	  lap_first = true;
	  lap++;
	}

      if (lap_first)
	{
	  lap_min_lat = lap_max_lat = p.location.latitude;
	  lap_min_long = lap_max_long = p.location.longitude;
	  lap_first = false;
	}
      else
	{
	  lap_min_lat = std::min(lap_min_lat, p.location.latitude);
	  lap_max_lat = std::max(lap_max_lat, p.location.latitude);
	  lap_min_long = std::min(lap_min_long, p.location.longitude);
	  lap_max_long = std::max(lap_max_long, p.location.longitude);
	}
    }

  if (lap != _laps.end())
    {
      location cen = location((min_lat + max_lat)*.5,
			      (min_long + max_long)*.5);
      location_size sz = location_size(max_lat - min_lat,
				       max_long - min_long);
      lap->region = location_region(cen, sz);
    }

  location cen = location((min_lat + max_lat)*.5, (min_long + max_long)*.5);
  location_size sz = location_size(max_lat - min_lat, max_long - min_long);
  _region = location_region(cen, sz);
}

void
activity::update_summary()
{
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
  _recovery_heart_rate = 0;
  _recovery_heart_rate_timestamp = 0;
  _avg_cadence = 0;
  _max_cadence = 0;
  _avg_vertical_oscillation = 0;
  _avg_stance_time = 0;
  _avg_stance_ratio = 0;

  if (_laps.size() > 0)
    {
      for (auto &it : _laps)
	{
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
	  _avg_vertical_oscillation
	    += it.avg_vertical_oscillation * it.total_duration;
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

      if (recovery_heart_rate() != 0)
	{
	  format_heart_rate(tem, recovery_heart_rate(),
			    unit_type::beats_per_minute);
	  fprintf(fh, "Recovery-HR: %s\n", tem.c_str());
	  tem.clear();
	}
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
  if (_laps.size() == 0)
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
  for (const auto &it : _laps)
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

void
activity::print_points(FILE *fh) const
{
  if (_points.size() == 0)
    return;

  fprintf(fh, "    %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s\n",
	  "Elapsed", "Timer", "Lat", "Long", "Alt", "Dist", "Speed",
	  "HR", "Cad", "V.O.", "St.T", "St.R");

  for (const auto &p : _points)
    {
      fprintf(fh, "    %10g %10g %10g %10g %10g %10g %10g %10g %10g %10g %10g %10g\n",
	      p.elapsed_time, p.timer_time, p.location.latitude,
	      p.location.longitude, p.altitude, p.distance, p.speed,
	      p.heart_rate, p.cadence, p.vertical_oscillation,
	      p.stance_time, p.stance_ratio);
    }

  fputc('\n', fh);
}

activity::point::field_fn
activity::point::field_function(point_field field)
{
  switch (field)
    {
    case point_field::timer_time:
      return [] (const point &p) -> float {return p.timer_time;};

    case point_field::elapsed_time:
      return [] (const point &p) -> float {return p.elapsed_time;};

    case point_field::altitude:
      return [] (const point &p) -> float {return p.altitude;};

    case point_field::distance:
      return [] (const point &p) -> float {return p.distance;};

    case point_field::speed:
      return [] (const point &p) -> float {return p.speed;};

    case point_field::pace:
      return [] (const point &p) -> float {return 1 / p.speed;};

    case point_field::heart_rate:
      return [] (const point &p) -> float {return p.heart_rate;};

    case point_field::cadence:
      return [] (const point &p) -> float {return p.cadence;};

    case point_field::vertical_oscillation:
      return [] (const point &p) -> float {return p.vertical_oscillation;};

    case point_field::stance_time:
      return [] (const point &p) -> float {return p.stance_time;};

    case point_field::stance_ratio:
      return [] (const point &p) -> float {return p.stance_ratio;};

    case point_field::stride_length:
      return [] (const point &p) -> float {
	return p.cadence != 0 ? p.speed / (p.cadence * (1/60.)) : 0;};

    case point_field::efficiency:
      return [] (const point &p) -> float {
	return p.speed != 0 ? (p.heart_rate * (1/60.)) / p.speed : 0;};

    default:
      return nullptr;
    }
}

void
activity::point::add(const point &x)
{
  location.latitude += x.location.latitude;
  location.longitude += x.location.longitude;
  elapsed_time += x.elapsed_time;
  timer_time += x.timer_time;
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
  location.latitude -= x.location.latitude;
  location.longitude -= x.location.longitude;
  elapsed_time -= x.elapsed_time;
  timer_time -= x.timer_time;
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
  location.latitude *= x;
  location.longitude *= x;
  elapsed_time *= x;
  timer_time *= x;
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
activity::get_range(point_field field, float &ret_min, float &ret_max) const
{
  float min = FLT_MAX, max = FLT_MIN;

  if (_points.size() != 0)
    {
      bool monotonic;
      switch (field)
	{
	case point_field::elapsed_time:
	case point_field::timer_time:
	case point_field::distance:
	  monotonic = true;
	  break;
	default:
	  monotonic = false;
	  break;
	}

      point::field_fn fn = point::field_function(field);

      if (monotonic)
	{
	  for (ssize_t i = 0; i < _points.size(); i++)
	    {
	      float value = fn(_points[i]);
	      if (_points[i].distance == 0 || !(value > 0))
		continue;
	      min = value;
	      break;
	    }

	  for (ssize_t i = _points.size() - 1; i >= 0; i--)
	    {
	      float value = fn(_points[i]);
	      if (_points[i].distance == 0 || !(value > 0))
		continue;
	      max = value;
	      break;
	    }

	  if (min > max)
	    std::swap(min, max);
	}
      else
	{
	  for (const auto &p : _points)
	    {
	      float value = fn(p);
	      if (p.distance == 0 || !(value > 0))
		continue;

	      min = std::min(min, value);
	      max = std::max(max, value);
	    }
	}
    }

  ret_min = min;
  ret_max = max;
}

void
activity::get_range(point_field field, float &ret_min, float &ret_max,
		    float &ret_mean, float &ret_sdev) const
{
  float min = 0, max = 0, total = 0, total_sq = 0;
  int samples = 0;

  point::field_fn fn = point::field_function(field);

  for (const auto &p : _points)
    {
      float value = fn(p);

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

  ret_min = min;
  ret_max = max;

  if (samples > 0)
    {
      float recip = 1.f / samples;
      ret_mean = total * recip;
      ret_sdev = sqrtf(total_sq * recip - ret_mean * ret_mean);
    }
  else
    ret_mean = 0, ret_sdev = 0;
}

void
activity::copy_summary(const activity &src)
{
  _activity_id = src._activity_id;
  _sport = src._sport;
  _device = src._device;

  _has_location = src._has_location;
  _has_distance = src._has_distance;
  _has_speed = src._has_speed;
  _has_heart_rate = src._has_heart_rate;
  _has_cadence = src._has_cadence;
  _has_altitude = src._has_altitude;
  _has_dynamics = src._has_dynamics;

  _region = src._region;

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
  _recovery_heart_rate = src._recovery_heart_rate;
  _recovery_heart_rate_timestamp = src._recovery_heart_rate_timestamp;
  _avg_cadence = src._avg_cadence;
  _max_cadence = src._max_cadence;
  _avg_vertical_oscillation = src._avg_vertical_oscillation;
  _avg_stance_time = src._avg_stance_time;
  _avg_stance_ratio = src._avg_stance_ratio;
}

namespace {

/* Composable gps track manipulations. */

template<typename Iterator>
struct input_stream
{
  Iterator p;
  Iterator end;

  input_stream(Iterator begin, Iterator end);
  input_stream(const input_stream &rhs);

  bool next(activity::point &p);
};

template<typename Stream>
struct resampler_stream
{
  Stream src;
  float sample_width;

  activity::point p[2];
  activity::point *p0;
  activity::point *p1;
  bool p1_valid;

  float t;

  resampler_stream(Stream src, float sample_width);
  resampler_stream(const resampler_stream &rhs);

  bool next(activity::point &p);
};

template<typename Stream>
struct box_stream
{
  Stream s_in;
  Stream s_out;
  bool s_in_valid;

  int filter_width;

  activity::point sum;
  int sum_n;
  int total;

  box_stream(Stream src, int filter_width);
  box_stream(const box_stream &rhs);

  bool next(activity::point &p);
};

template<typename Iterator> inline
input_stream<Iterator>::input_stream (Iterator begin_, Iterator end_)
: p(begin_),
  end(end_)
{
}

template<typename Iterator> inline
input_stream<Iterator>::input_stream (const input_stream &rhs)
: input_stream(rhs.p, rhs.end)
{
}

template<typename Iterator> inline bool
input_stream<Iterator>::next(activity::point &ret_p)
{
  if (p != end)
    {
      ret_p = *p++;
      return true;
    }
  else
    return false;
}

template<typename Stream> inline
resampler_stream<Stream>::resampler_stream (Stream src_, float sample_width_)
: src(src_),
  sample_width(sample_width_)
{
  p0 = p + 0;
  p1 = p + 1;

  if (src.next(*p0))
    p1_valid = src.next(*p1);
  else
    p1_valid = false;

  t = p0->timer_time;
}

template<typename Stream> inline
resampler_stream<Stream>::resampler_stream(const resampler_stream &rhs)
: resampler_stream(rhs.src, rhs.sample_width)
{
}

template<typename Stream> bool
resampler_stream<Stream>::next(activity::point &ret_p)
{
  /* Standard (crap) linear interpolator with clamp-to-edge behavior. */

  if (p1_valid)
    {
      while (!(t < p1->timer_time))
	{
	  /* swap pointers to avoid copying all the fields. */

	  using std::swap;
	  swap(p0, p1);

	  p1_valid = src.next(*p1);

	  if (!p1_valid)
	    {
	      ret_p = *p0;
	      return true;
	    }

	  if (!p1->follows_continuously(*p0))
	    {
	      t = p1->timer_time;
	      ret_p = *p0;
	      return true;
	    }
	}

      if (t < p0->timer_time)
	t = p0->timer_time;

      float f = (t - p0->timer_time) / (p1->timer_time - p0->timer_time);
      t += sample_width;

      mix(ret_p, *p0, *p1, f);
      return true;
    }

  return false;
}

template<typename Stream> inline
box_stream<Stream>::box_stream(Stream src_, int filter_width_)
: s_in(src_),
  s_out(src_),
  s_in_valid(true),
  filter_width(filter_width_),
  sum_n(0),
  total(0)
{
}

template<typename Stream> inline
box_stream<Stream>::box_stream(const box_stream &rhs)
: box_stream(rhs.s_in, rhs.filter_width)
{
}

template<typename Stream> bool
box_stream<Stream>::next(activity::point &ret_p)
{
  if (s_in_valid)
    {
      if (total >= filter_width)
	{
	  activity::point p;
	  s_out.next(p);
	  sum.sub(p);
	  sum_n--;
	}

      activity::point p;
      s_in_valid = s_in.next(p);
      if (!s_in_valid)
	return false;

      sum.add(p);
      sum_n++;
      total++;

      ret_p = sum;
      ret_p.mul(1.f / sum_n);

      /* FIXME: better way to avoid smoothing time/distance fields?
	 Or perhaps should smooth distance sample deltas? */

      ret_p.elapsed_time = p.elapsed_time;
      ret_p.timer_time = p.timer_time;
      ret_p.distance = p.distance;

      return true;
    }
  else
    return false;
}

template<typename T> inline input_stream<T>
make_input_stream(T begin, T end) {
  return input_stream<T>(begin, end);
}

template <typename T> inline resampler_stream<T>
make_resampler_stream(T src, float sample_width) {
  return resampler_stream<T>(src, sample_width);
}

template <typename T> inline box_stream<T>
make_box_stream(T src, int filter_width) {
  return box_stream<T>(src, filter_width);
}

} // anonymous namespace

void
activity::smooth(const activity &src, int width)
{
  copy_summary(src);
  _laps = src._laps;

  /* Resample to one second intervals, smooth across width samples,
     resample to five second intervals. */

  auto input = make_input_stream(src._points.begin(), src._points.end());
  auto resampled = make_resampler_stream(input, 1);
  auto averaged = make_box_stream(resampled, width);
  auto filter = make_resampler_stream(averaged, 5);

  point p;
  while (filter.next(p))
    _points.push_back(p);
}

bool
activity::point_at(point_field field, float x, point &ret_p) const
{
  auto p = points_from(field, x);

  if (p != _points.end())
    {
      if (p != _points.begin())
	{
	  point::field_fn fn = point::field_function(field);

	  auto last_p = p - 1;

	  float px = fn(*p);
	  float last_px = fn(*last_p);

	  float f = (px - x) / (px - last_px);

	  mix(ret_p, *p, *last_p, f);
	  return true;
	}
    }

  return false;
}

} // namespace gps

void
mix(gps::activity::point &a, const gps::activity::point &b,
  const gps::activity::point &c, float f)
{
  mix(a.location, b.location, c.location, f);
  mix(a.elapsed_time, b.elapsed_time, c.elapsed_time, f);
  mix(a.timer_time, b.timer_time, c.timer_time, f);
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
