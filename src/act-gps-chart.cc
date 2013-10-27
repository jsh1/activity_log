// -*- c-style: gnu -*-

#include "act-gps-chart.h"

#include "act-config.h"
#include "act-format.h"

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
  if (type == x_axis_type::DISTANCE)
    {
      field = &activity::point::distance;
      min_value = chart._min_distance;
      max_value = chart._max_distance;
    }
  else // if (type == x_axis_type::DURATION)
    {
      field = &activity::point::timestamp;
      min_value = chart._min_time;
      max_value = chart._max_time;
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
    case value_conversion::IDENTITY:
      return x;
    case value_conversion::HEARTRATE_BPM_HRR: {
      const config &cfg = shared_config();
      return (x - cfg.resting_hr()) / (cfg.max_hr() - cfg.resting_hr()) * 100.; }
    case value_conversion::HEARTRATE_BPM_PMAX: {
      const config &cfg = shared_config();
      return x / cfg.max_hr() * 100.; }
    case value_conversion::SPEED_MS_PACE_MI:
      return x > 0 ? SECS_PER_MILE(x) : 0;
    case value_conversion::SPEED_MS_PACE_KM:
      return x > 0 ? SECS_PER_KM(x) : 0;
    case value_conversion::SPEED_MS_MPH:
      return x * (MILES_PER_METER * 3600);
    case value_conversion::SPEED_MS_KPH:
      return x * (KM_PER_METER * 3600);
    case value_conversion::DISTANCE_M_MI:
      return x * MILES_PER_METER;
    case value_conversion::DISTANCE_M_FT:
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
    case value_conversion::IDENTITY:
      return x;
    case value_conversion::HEARTRATE_BPM_HRR: {
      const config &cfg = shared_config();
      return x * (1./100) * (cfg.max_hr() - cfg.resting_hr()) + cfg.resting_hr(); }
    case value_conversion::HEARTRATE_BPM_PMAX: {
      const config &cfg = shared_config();
      return x * (1./100) * cfg.max_hr(); }
    case value_conversion::SPEED_MS_PACE_MI:
      return x > 0 ? MILES_PER_SEC(x) : 0;
    case value_conversion::SPEED_MS_PACE_KM:
      return x > 0 ? KM_PER_SEC(x) : 0;
    case value_conversion::SPEED_MS_MPH:
      return x * (1. / (MILES_PER_METER * 3600));
    case value_conversion::SPEED_MS_KPH:
      return x * (1. / (KM_PER_METER * 3600));
    case value_conversion::DISTANCE_M_MI:
      return x * (1. / MILES_PER_METER);
    case value_conversion::DISTANCE_M_FT:
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
    case value_conversion::HEARTRATE_BPM_HRR:
    case value_conversion::HEARTRATE_BPM_PMAX:
      tick_delta = 5;
      scale_ticks = false;
      break;
    case value_conversion::SPEED_MS_PACE_MI:
    case value_conversion::SPEED_MS_PACE_KM:
      tick_delta = 15;
      scale_ticks = false;
      break;
    case value_conversion::SPEED_MS_MPH:
    case value_conversion::SPEED_MS_KPH:
      tick_delta = 1;
      break;
    case value_conversion::DISTANCE_M_FT:
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
      format_distance(s, value, conversion == value_conversion::DISTANCE_M_FT
		      ? unit_type::feet : unit_type::metres);
    }
  else if (field == &activity::point::speed)
    {
      if (conversion == value_conversion::SPEED_MS_PACE_MI)
	format_pace(s, value, unit_type::seconds_per_mile);
      else if (conversion == value_conversion::SPEED_MS_PACE_KM)
	format_pace(s, value, unit_type::seconds_per_kilometre);
      else if (conversion == value_conversion::SPEED_MS_MPH)
	format_speed(s, value, unit_type::miles_per_hour);
      else if (conversion == value_conversion::SPEED_MS_KPH)
	format_speed(s, value, unit_type::kilometres_per_hour);
    }
  else if (field == &activity::point::heart_rate)
    {
      unit_type unit = unit_type::beats_per_minute;
      if (conversion == value_conversion::HEARTRATE_BPM_HRR)
	unit = unit_type::percent_hr_reserve;
      else if (conversion == value_conversion::HEARTRATE_BPM_PMAX)
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
chart::point_at_x(CGFloat x, x_axis_type type, activity::point &ret_p) const
{
  x_axis_state x_axis(*this, type);

  for (const auto &lap : _activity.laps())
    {
      double lt0 = lap.start_time * x_axis.xm + x_axis.xc;
      double lt1 = lt0 + lap.total_elapsed_time * x_axis.xm;

      if (lt1 < x)
	continue;
      if (lt0 > x)
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
