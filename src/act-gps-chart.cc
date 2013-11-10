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

#include "act-gps-chart.h"

#include "act-config.h"
#include "act-format.h"
#include "act-intensity-points.h"

#include <math.h>

#define MILES_PER_METER 0.000621371192
#define KM_PER_METER 1e-3
#define FEET_PER_METER 3.2808399

#define SECS_PER_MILE(x) ((1. /  (x)) * (1. / MILES_PER_METER))
#define MILES_PER_SEC(x) (1. / ((x) * MILES_PER_METER))

#define SECS_PER_KM(x) ((1. /  (x)) * (1. / KM_PER_METER))
#define KM_PER_SEC(x) (1. / ((x) * KM_PER_METER))

#define MAX_TICKS 50
#define MIN_TICKS 5

namespace act {
namespace gps {

chart::x_axis_state::x_axis_state(const chart &chart, x_axis_type type)
{
  switch (type)
    {
    case x_axis_type::distance:
      field = &activity::point::distance;
      min_value = chart._min_distance;
      max_value = chart._max_distance;
      break;

    case x_axis_type::elapsed_time:
      field = &activity::point::timestamp;
      min_value = chart._min_time;
      max_value = chart._max_time;
      break;
    }

  CGFloat x_scale = 1. / (max_value - min_value);

  /* x' = (x - min_v) * v_scale * chart_w + chart_x
        = x * v_scale * chart_w - min_v * v_scale * chart_w + chart_x
	v_scale = 1 / (max_v - min_v). */

  xm = x_scale * chart._chart_rect.size.width;
  xc = (chart._chart_rect.origin.x
	- min_value * x_scale * chart._chart_rect.size.width);
}

double
chart::line::convert_from_si(double x) const
{
  switch (conversion)
    {
    case value_conversion::identity:
      return x;
    case value_conversion::heartrate_bpm_hrr: {
      const config &cfg = shared_config();
      return (x - cfg.resting_hr()) / (cfg.max_hr() - cfg.resting_hr()) * 100.; }
    case value_conversion::heartrate_bpm_pmax: {
      const config &cfg = shared_config();
      return x / cfg.max_hr() * 100.; }
    case value_conversion::speed_ms_pace_mi:
      return x > 0 ? SECS_PER_MILE(x) : 0;
    case value_conversion::speed_ms_pace_km:
      return x > 0 ? SECS_PER_KM(x) : 0;
    case value_conversion::speed_ms_mph:
      return x * (MILES_PER_METER * 3600);
    case value_conversion::speed_ms_kph:
      return x * (KM_PER_METER * 3600);
    case value_conversion::speed_ms_vvo2max: {
      const config &cfg = shared_config();
      if (cfg.vdot() != 0)
	return x > 0 ? (x / vvo2_max(cfg.vdot())) * 100 : 0;
      else
	return 0; }
    case value_conversion::distance_m_mi:
      return x * MILES_PER_METER;
    case value_conversion::distance_m_ft:
      return x * FEET_PER_METER;
    default:
      return x;
    }
}

double
chart::line::convert_to_si(double x) const
{
  switch (conversion)
    {
    case value_conversion::identity:
      return x;
    case value_conversion::heartrate_bpm_hrr: {
      const config &cfg = shared_config();
      return x * (1./100) * (cfg.max_hr() - cfg.resting_hr()) + cfg.resting_hr(); }
    case value_conversion::heartrate_bpm_pmax: {
      const config &cfg = shared_config();
      return x * (1./100) * cfg.max_hr(); }
    case value_conversion::speed_ms_pace_mi:
      return x > 0 ? MILES_PER_SEC(x) : 0;
    case value_conversion::speed_ms_pace_km:
      return x > 0 ? KM_PER_SEC(x) : 0;
    case value_conversion::speed_ms_mph:
      return x * (1. / (MILES_PER_METER * 3600));
    case value_conversion::speed_ms_kph:
      return x * (1. / (KM_PER_METER * 3600));
    case value_conversion::speed_ms_vvo2max: {
      const config &cfg = shared_config();
      if (cfg.vdot() != 0)
	return x * .01 * vvo2_max(cfg.vdot());
      else
	return 0; }
    case value_conversion::distance_m_mi:
      return x * (1. / MILES_PER_METER);
    case value_conversion::distance_m_ft:
      return x * (1. / FEET_PER_METER);
    default:
      return x;
    }
}

void
chart::line::update_values(const chart &c)
{
  const activity &a = c._activity;

  double mean, sdev;
  a.get_range(field, min_value, max_value, mean, sdev);

  double border = (max_value - min_value) * .05;
  min_value -= border;
  max_value += border;

  if (field == &activity::point::speed)
    {
      min_value = mean - 3 * sdev;
      max_value = mean + 3 * sdev;
    }
  else if (field == &activity::point::altitude)
    {
      if (max_value - min_value < 100)
	max_value = min_value + 100;
    }

  double range = max_value - min_value;
  scaled_min_value = min_value + range * min_ratio;
  scaled_max_value = min_value + range * max_ratio;

  tick_min = convert_from_si(min_value);
  tick_max = convert_from_si(max_value);

  if (tick_max < tick_min)
    std::swap(tick_min, tick_max);

  bool scale_ticks = true;

  switch (conversion)
    {
    case value_conversion::heartrate_bpm_hrr:
    case value_conversion::heartrate_bpm_pmax:
      tick_delta = 5;
      scale_ticks = false;
      break;
    case value_conversion::speed_ms_pace_mi:
    case value_conversion::speed_ms_pace_km:
      tick_delta = 15;
      scale_ticks = false;
      break;
    case value_conversion::speed_ms_mph:
    case value_conversion::speed_ms_kph:
      tick_delta = 1;
      break;
    case value_conversion::distance_m_ft:
      tick_delta = 50;
      scale_ticks = false;
      break;
    default:
      tick_delta = 5;
    }

  if (scale_ticks)
    {
      while ((tick_max - tick_min) / tick_delta > MAX_TICKS)
	tick_delta = tick_delta * 2;
      while ((tick_max - tick_min) / tick_delta < MIN_TICKS)
	tick_delta = tick_delta * .5;
    }

  tick_min = floor(tick_min / tick_delta) * tick_delta;
  tick_max = ceil(tick_max / tick_delta) * tick_delta;
}

void
chart::line::format_tick(std::string &s, double tick, double value) const
{
  if (field == &activity::point::altitude)
    {
      format_distance(s, value, conversion == value_conversion::distance_m_ft
		      ? unit_type::feet : unit_type::metres);
    }
  else if (field == &activity::point::speed)
    {
      if (conversion == value_conversion::speed_ms_pace_mi)
	format_pace(s, value, unit_type::seconds_per_mile);
      else if (conversion == value_conversion::speed_ms_pace_km)
	format_pace(s, value, unit_type::seconds_per_kilometre);
      else if (conversion == value_conversion::speed_ms_mph)
	format_speed(s, value, unit_type::miles_per_hour);
      else if (conversion == value_conversion::speed_ms_kph)
	format_speed(s, value, unit_type::kilometres_per_hour);
      else if (conversion == value_conversion::speed_ms_vvo2max)
	{
	  char buf[32];
	  snprintf(buf, sizeof(buf), "%d%% vVO2", (int) tick);
	  s.append(buf);
	}
    }
  else if (field == &activity::point::heart_rate)
    {
      unit_type unit = unit_type::beats_per_minute;
      if (conversion == value_conversion::heartrate_bpm_hrr)
	unit = unit_type::percent_hr_reserve;
      else if (conversion == value_conversion::heartrate_bpm_pmax)
	unit = unit_type::percent_hr_max;
      format_heart_rate(s, value, unit);
    }
  else
    {
      format_number(s, tick);
    }
}

chart::chart(const activity &a, x_axis_type xa)
: _activity(a),
  _x_axis(xa),
  _chart_rect(CGRectNull),
  _selected_lap(-1),
  _current_time(-1)
{
  double mean, sdev;
  a.get_range(&activity::point::timestamp,
	      _min_time, _max_time, mean, sdev);
  a.get_range(&activity::point::distance,
	      _min_distance, _max_distance, mean, sdev);
}

void
chart::add_line(double activity::point:: *field, value_conversion conv,
		line_color color, uint32_t flags, double min_ratio,
		double max_ratio)
{
  _lines.push_back(line(field, conv, color, flags, min_ratio, max_ratio));
}

bool
chart::point_at_x(CGFloat x, activity::point &ret_p) const
{
  x_axis_state x_axis(*this, _x_axis);

  double total_dist = 0;

  for (const auto &lap : _activity.laps())
    {
      double lx0, lx1;

      if (_x_axis == x_axis_type::elapsed_time)
	{
	  lx0 = lap.start_time * x_axis.xm + x_axis.xc;
	  lx1 = lx0 + lap.total_elapsed_time * x_axis.xm;
	}
      else
	{
	  lx0 = total_dist * x_axis.xm + x_axis.xc;
	  lx1 = lx0 + lap.total_distance * x_axis.xm;
	}

      total_dist += lap.total_distance;

      if (lx1 < x)
	continue;
      if (lx0 > x)
	return false;

      const activity::point *last_p = nullptr;
      CGFloat last_x = 0;

      for (const auto &it : lap.track)
	{
	  double it_value = it.*x_axis.field;
	  if (it_value == 0)
	    continue;

	  CGFloat it_x = it_value * x_axis.xm + x_axis.xc;

	  if (it_x > x)
	    {
	      if (last_p != nullptr)
		{
		  double f = (it_x - x) / (it_x - last_x);
		  mix(ret_p, *last_p, it, 1-f);
		  return true;
		}
	      else
		return false;
	    }
      
	  last_p = &it;
	  last_x = it_x;
	}
    }

  return false;
}

void
chart::remove_all_lines()
{
  _lines.resize(0);
}

void
chart::update_values()
{
  for (size_t i = 0; i < _lines.size(); i++)
    _lines[i].update_values(*this);
}

} // namespace gps
} // namespace act
