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
#define MIN_TICK_GAP 30

#define KEY_TEXT_WIDTH 60

#define LABEL_FONT "Lucida Grande"
#define LABEL_SIZE 9

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
      field = &activity::point::time;
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
  a.get_range(&activity::point::time, _min_time, _max_time, mean, sdev);
  a.get_range(&activity::point::distance, _min_distance,
	      _max_distance, mean, sdev);
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
      double lt0 = lap.time * x_axis.xm + x_axis.xc;
      double lt1 = lt0 + lap.duration * x_axis.xm;

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

void
chart::draw(CGContextRef ctx)
{
  x_axis_state x_axis(*this, _x_axis);

  CGFloat tl = _chart_rect.origin.x;
  CGFloat tr = tl + _chart_rect.size.width;

  for (size_t i = 0; i < _lines.size(); i++)
    {
      CGFloat tx;
      if (!(_lines[i].flags & RIGHT_TICKS))
	tx = tl, tl += KEY_TEXT_WIDTH;
      else
	tr -= KEY_TEXT_WIDTH, tx = tr;

      draw_line(ctx, _lines[i], x_axis, tx);
    }

  draw_lap_markers(ctx, x_axis);

  draw_current_time(ctx);
}

void
chart::draw_line(CGContextRef ctx, const line &l,
		 const x_axis_state &x_axis, CGFloat tx)
{
  /* x' = (x - min_v) * v_scale * chart_w + chart_x
        = x * v_scale * chart_w - min_v * v_scale * chart_w + chart_x
	v_scale = 1 / (max_v - min_v). */

  CGFloat y_scale = 1. / (l.scaled_max_value - l.scaled_min_value);
  CGFloat y0 = (_chart_rect.origin.y
		- l.scaled_min_value * y_scale * _chart_rect.size.height);
  CGFloat ym = y_scale * _chart_rect.size.height;

  CGMutablePathRef path = CGPathCreateMutable();

  bool first_pt = true;
  CGFloat first_x = 0, first_y = 0;
  CGFloat last_x = 0, last_y = 0;

  // basic smoothing to avoid rendering multiple data points per pixel

  double skipped_total = 0, skipped_count = 0;
  
  for (size_t li = 0; li < _activity.laps().size(); li++)
    {
      const activity::lap &lap = _activity.laps()[li];
      const activity::point *track = &lap.track[0];

      for (size_t ti = 0; ti < lap.track.size(); ti++)
	{
	  const activity::point &p = track[ti];
	  double dist = p.*x_axis.field;
	  double value = p.*(l.field);
	  if (dist == 0 || value == 0)
	    continue;
	  CGFloat x = dist * x_axis.xm + x_axis.xc;
	  if (first_pt || x - last_x >= 1)
	    {
	      if (skipped_count > 0)
		{
		  value = (value + skipped_total) / (skipped_count + 1);
		  skipped_total = skipped_count = 0;
		}
	      CGFloat y = value * ym + y0;
	      if (first_pt)
		{
		  CGPathMoveToPoint(path, 0, x, y);
		  first_x = x, first_y = y, first_pt = false;
		}
	      else
		CGPathAddLineToPoint(path, 0, x, y);
	      last_x = x, last_y = y;
	    }
	  else
	    skipped_total += value, skipped_count += 1;
	}
    }

  CGMutablePathRef fill_path = CGPathCreateMutableCopy(path);
  CGPathAddLineToPoint(fill_path, 0, last_x, _chart_rect.origin.y);
  CGPathAddLineToPoint(fill_path, 0, first_x, _chart_rect.origin.y);
  CGPathAddLineToPoint(fill_path, 0, first_x, first_y);
  CGPathCloseSubpath(fill_path);

  CGContextSaveGState(ctx);

  // Flip y axis so values grow upwards to match chart.

  CGContextTranslateCTM(ctx, _chart_rect.origin.x,
			_chart_rect.origin.y + _chart_rect.size.height);
  CGContextScaleCTM(ctx, 1, -1);
  CGContextTranslateCTM(ctx, -_chart_rect.origin.x, -_chart_rect.origin.y);

  CGFloat fill_rgb[3], stroke_rgb[3];

  switch (l.color)
    {
    case line_color::RED:
      fill_rgb[0] = 1;
      fill_rgb[1] = .5;
      fill_rgb[2] = .5;
      stroke_rgb[0] = 1;
      stroke_rgb[1] = 0;
      stroke_rgb[2] = 0.3;
      break;
    case line_color::GREEN:
      fill_rgb[0] = .75;
      fill_rgb[1] = 1;
      fill_rgb[2] = .75;
      stroke_rgb[0] = 0;
      stroke_rgb[1] = 0.6;
      stroke_rgb[2] = 0.2;
      break;
    case line_color::BLUE:
      fill_rgb[0] = .5;
      fill_rgb[1] = .5;
      fill_rgb[2] = 1;
      stroke_rgb[0] = 0;
      stroke_rgb[1] = 0.2;
      stroke_rgb[2] = 1;
      break;
    case line_color::ORANGE:
      fill_rgb[0] = 1;
      fill_rgb[1] = .5;
      fill_rgb[2] = 0;
      stroke_rgb[0] = 1;
      stroke_rgb[1] = 0.5;
      stroke_rgb[2] = 0;
      break;
    case line_color::GRAY:
      fill_rgb[0] = .6;
      fill_rgb[1] = .6;
      fill_rgb[2] = .6;
      stroke_rgb[0] = 0.6;
      stroke_rgb[1] = 0.6;
      stroke_rgb[2] = 0.6;
      break;
    }

  // Fill gradient under the line

  if (l.flags & FILL_BG)
    {
      CGContextSaveGState(ctx);

      if (l.flags & OPAQUE_BG)
	{
	  // D = S + D * (1-Sa)
	  // C' = C*F + (1-F)  [assuming white background]

	  CGContextSetRGBFillColor(ctx, .8+fill_rgb[0]*.2,
				   .8+fill_rgb[1]*.2, .8+fill_rgb[2]*.2, 1);
	}
      else
	{
	  CGContextSetRGBFillColor(ctx, fill_rgb[0],
				   fill_rgb[1], fill_rgb[2], .2);
	}

      CGContextAddPath(ctx, fill_path);
      CGContextFillPath(ctx);

      CGContextRestoreGState(ctx);
    }

  // Draw data line

  if (!(l.flags & NO_STROKE))
    {
      CGContextSaveGState(ctx);
      CGContextSetRGBStrokeColor(ctx, stroke_rgb[0], stroke_rgb[1],
				 stroke_rgb[2], 1);
      CGContextAddPath(ctx, path);
      CGContextSetLineWidth(ctx, 1.75);
      CGContextSetLineJoin(ctx, kCGLineJoinBevel);
      CGContextStrokePath(ctx);
      CGContextRestoreGState(ctx);
    }

  // Draw 'tick' lines at sensible points around the value's range.

  CGContextSaveGState(ctx);

  CGContextSetLineWidth(ctx, 1);
  CGContextSetRGBStrokeColor(ctx, stroke_rgb[0], stroke_rgb[1], stroke_rgb[2], .25);
  static const CGFloat dash[] = {4, 2};
  CGContextSetLineDash(ctx, 0, dash, 2);

  CGContextSelectFont(ctx, LABEL_FONT, LABEL_SIZE, kCGEncodingMacRoman);
  CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
  CGContextSetTextDrawingMode(ctx, kCGTextFill);
  CGContextSetGrayFillColor(ctx, 0.1, 1);
  CGContextSetRGBFillColor(ctx, stroke_rgb[0], stroke_rgb[1], stroke_rgb[2], 1);

  CGFloat lly = _chart_rect.origin.y;
  CGFloat ury = lly + _chart_rect.size.height;
  CGFloat ly = HUGE_VAL;

  for (double tick = l.tick_min; tick < l.tick_max; tick += l.tick_delta)
    {
      double value = l.convert_to_si(tick);
      CGFloat y = floor(value * ym + y0) + .5;

      if (y < lly || y > ury)
	continue;
      if (fabs(y - ly) < MIN_TICK_GAP)
	continue;

      if (l.flags & TICK_LINES)
	{
	  CGPoint lines[2];
	  lines[0] = CGPointMake(_chart_rect.origin.x, y);
	  lines[1] = CGPointMake(_chart_rect.origin.x
				 + _chart_rect.size.width, y);
	  CGContextStrokeLineSegments(ctx, lines, 2);
	}

      std::string s;
      l.format_tick(s, tick, value);

      CGContextShowTextAtPoint(ctx, tx + 2, y + 2, s.c_str(), s.size());

      ly = y;
    }

  CGContextRestoreGState(ctx);

  CGContextRestoreGState(ctx);

  CGPathRelease(fill_path);
  CGPathRelease(path);
}

void
chart::draw_lap_markers(CGContextRef ctx, const x_axis_state &x_axis)
{
  std::vector<CGPoint> lines;
  lines.reserve(2 * (_activity.laps().size() + 1));

  CGFloat total_dist = _x_axis == x_axis_type::DISTANCE ? 0 : _activity.time();

  for (size_t i = 0; true; i++)
    {
      CGFloat x = total_dist * x_axis.xm + x_axis.xc;
      x = floor(x) + 0.5;

      lines.push_back(CGPointMake(x, _chart_rect.origin.y));
      lines.push_back(CGPointMake(x, _chart_rect.origin.y
				  + _chart_rect.size.height));

      if (!(i < _activity.laps().size()))
	break;

      if (_x_axis == x_axis_type::DISTANCE)
	total_dist += _activity.laps()[i].distance;
      else
	total_dist = _activity.laps()[i].time + _activity.laps()[i].duration;
    }

  CGContextSaveGState(ctx);

  CGContextSetLineWidth(ctx, 1);
  static const CGFloat dash[] = {4, 2};
  CGContextSetLineDash(ctx, 0, dash, 2);
  CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.1);
  CGContextStrokeLineSegments(ctx, &lines[2], lines.size() - 4);

  if (_selected_lap >= 0 && _selected_lap < _activity.laps().size())
    {
      CGContextSetRGBFillColor(ctx, .4, .4, .8, .2);
      CGContextSetBlendMode(ctx, kCGBlendModePlusDarker);

      const CGPoint &p0 = lines[_selected_lap*2];
      const CGPoint &p1 = lines[_selected_lap*2+3];
      CGRect r = CGRectMake(p0.x, p0.y, p1.x - p0.x, p1.y - p0.y);
      CGContextFillRect(ctx, r);
    }

  CGContextRestoreGState(ctx);
}

void
chart::draw_current_time(CGContextRef ctx)
{
  if (_current_time < 0)
    return;

  // always need time axis calibration for this.

  x_axis_state x_axis(*this, x_axis_type::DURATION);

  double t = _activity.time() + _current_time;

  if (t < x_axis.min_value || t > x_axis.max_value)
    return;

  CGFloat x = round(t * x_axis.xm + x_axis.xc);

  CGContextSetGrayFillColor(ctx, 0.25, 1);
  CGContextFillRect(ctx, CGRectMake(x, _chart_rect.origin.y,
				    1, _chart_rect.size.height));
}

CGRect
chart::current_time_rect() const
{
  if (_current_time < 0)
    return CGRectNull;

  x_axis_state x_axis(*this, x_axis_type::DURATION);

  double t = _activity.time() + _current_time;

  if (t < x_axis.min_value || t > x_axis.max_value)
    return CGRectNull;

  CGFloat x = round(t * x_axis.xm + x_axis.xc);

  return CGRectMake(x, _chart_rect.origin.y,
		    1, _chart_rect.size.height);
}

} // namespace gps
} // namespace act
