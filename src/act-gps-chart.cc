// -*- c-style: gnu -*-

#include "act-gps-chart.h"

#include "act-config.h"

#include <math.h>

#define MILES_PER_METER 0.000621371192
#define FEET_PER_METER 3.2808399

#define MINUTES_PER_MILE(x) ((1. /  (x)) * (1. / (MILES_PER_METER * 60.)))

#define MAX_TICKS 8
#define MIN_TICKS 3

namespace act {
namespace gps {

void
chart::line::update_values(const chart &c)
{
  const activity &a = c._activity;

  double mean, sdev;
  a.get_range(field, min_value, max_value, mean, sdev);

  if (field == &activity::point::speed)
    {
      min_value = mean - 2.5 * sdev;
      max_value = mean + 2.5 * sdev;
    }
  else if (field == &activity::point::altitude)
    {
      if (max_value - min_value < 50)
	max_value = min_value + 50;
    }

  double range = max_value - min_value;
  scaled_min_value = min_value + range * min_ratio;
  scaled_max_value = min_value + range * max_ratio;

  if (field == &activity::point::altitude)
    {
      // Try to avoid making mountains out of molehills...

      double range = c._max_dist - c._min_dist;
      if (scaled_max_value - scaled_min_value < range * .01)
	scaled_max_value = scaled_min_value + range * .01;
    }
}

double
chart::line::convert_from_si(double x) const
{
  switch (conversion)
    {
    case IDENTITY:
      return x;
    case HEARTRATE_BPM_HRR: {
      const config &cfg = shared_config();
      return (x - cfg.resting_hr()) / (cfg.max_hr() - cfg.resting_hr()) * 100.; }
    case SPEED_MS_PACE:
      return x > 0 ? 1. / (x * MILES_PER_METER * 60.) : 0;
    case DISTANCE_M_MI:
      return x * MILES_PER_METER;
    case DISTANCE_M_FT:
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
    case IDENTITY:
      return x;
    case HEARTRATE_BPM_HRR: {
      const config &cfg = shared_config();
      return x * (1./100) * (cfg.max_hr() - cfg.resting_hr()) + cfg.resting_hr(); }
    case SPEED_MS_PACE:
      return x > 0 ? (1. / x) * (1. / (MILES_PER_METER * 60.)) : 0;
    case DISTANCE_M_MI:
      return x * (1. / MILES_PER_METER);
    case DISTANCE_M_FT:
      return x * (1. / FEET_PER_METER);
    default:
      return x;
    }
}

void
chart::line::tick_values(double &min_tick, double &max_tick,
			 double &delta) const
{
  min_tick = convert_from_si(min_value);
  max_tick = convert_from_si(max_value);
  if (max_tick < min_tick)
    std::swap(min_tick, max_tick);

  double tick_unit;
  switch (conversion)
    {
    case HEARTRATE_BPM_HRR:
      tick_unit = 10;
      break;
    case SPEED_MS_PACE:
      tick_unit = 0.5;
      break;
    case DISTANCE_M_FT:
      tick_unit = 100;
      break;
    default:
      tick_unit = 1;
    }

  while ((max_tick - min_tick) / tick_unit > MAX_TICKS)
    tick_unit = tick_unit * 2;
  while ((max_tick - min_tick) / tick_unit < MIN_TICKS)
    tick_unit = tick_unit * .5;

  min_tick = floor(min_tick / tick_unit) * tick_unit;
  max_tick = ceil(max_tick / tick_unit) * tick_unit;
  delta = tick_unit;
}

chart::chart(const activity &a)
: _activity(a)
{
  double mean, sdev;
  a.get_range(&activity::point::distance, _min_dist, _max_dist, mean, sdev);
}

void
chart::add_line(double activity::point:: *field, bool smoothed,
		value_conversion conv, line_color color,
		double min_ratio, double max_ratio)
{
  _lines.push_back(line(field, smoothed, conv, color, min_ratio, max_ratio));
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
chart::set_chart_rect(const CGRect &r)
{
  _chart_rect = r;
  update_values();
}

void
chart::draw(CGContextRef ctx)
{
  for (size_t i = 0; i < _lines.size(); i++)
    draw_line(ctx, _lines[i]);

  draw_lap_markers(ctx);
}

void
chart::draw_line(CGContextRef ctx, const line &l)
{
  /* x' = (x - min_v) * v_scale * chart_w + chart_x
        = x * v_scale * chart_w - min_v * v_scale * chart_w + chart_x
	v_scale = 1 / (max_v - min_v). */

  CGFloat x_scale = 1. / (_max_dist - _min_dist);
  CGFloat x0 = (_chart_rect.origin.x
		- _min_dist * x_scale * _chart_rect.size.width);
  CGFloat xm = x_scale * _chart_rect.size.width;

  CGFloat y_scale = 1. / (l.scaled_max_value - l.scaled_min_value);
  CGFloat y0 = (_chart_rect.origin.y
		- l.scaled_min_value * y_scale * _chart_rect.size.height);
  CGFloat ym = y_scale * _chart_rect.size.height;

  CGMutablePathRef path = CGPathCreateMutable();

  bool first_pt = true;
  CGFloat first_x = 0, first_y = 0;
  CGFloat last_x = 0, last_y = 0;

  for (size_t li = 0; li < _activity.laps().size(); li++)
    {
      const activity::lap &lap = _activity.laps()[li];
      const activity::point *track = &lap.track[0];

      for (size_t ti = 0; ti < lap.track.size(); ti++)
	{
	  const activity::point &p = track[ti];
	  double dist = p.distance;
	  double value = p.*(l.field);
	  if (dist == 0 || value == 0)
	    continue;
	  CGFloat x = dist * xm + x0;
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

  // Fill gradient under the line

  const CGFloat *fill_grad = 0;

  switch (l.color)
    {
      static const CGFloat red_grad[8] = {1, 0, 0.1, 0.4,
					  1, 0, 0.1, 0.1};
      static const CGFloat green_grad[8] = {0, 1, 0.25, 0.4,
					    0, 1, 0.25, 0.1};
      static const CGFloat blue_grad[8] = {0, 0.5, 1, 0.4,
					   0, 0.5, 1, 0.1};
      static const CGFloat orange_grad[8] = {1, 0.5, 0, 0.4,
					     1, 0.5, 0, 0.1};

    case RED:
      fill_grad = red_grad;
      break;
    case GREEN:
      fill_grad = green_grad;
      break;
    case BLUE:
      fill_grad = blue_grad;
      break;
    case ORANGE:
      fill_grad = orange_grad;
      break;
    }

  if (fill_grad)
    {
      CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
      CGGradientRef grad = CGGradientCreateWithColorComponents(space,
							fill_grad, 0, 2);
      CGColorSpaceRelease(space);
      CGContextSaveGState(ctx);
      CGContextAddPath(ctx, fill_path);
      CGContextClip(ctx);
      CGPoint p0 = CGPointMake(0, l.max_value * ym + y0);
      CGPoint p1 = CGPointMake(0, l.min_value * ym + y0);
      CGContextDrawLinearGradient(ctx, grad, p0, p1,
				  kCGGradientDrawsBeforeStartLocation
				  | kCGGradientDrawsAfterEndLocation);
      CGContextRestoreGState(ctx);
      CGGradientRelease(grad);
    }

  // Draw 'tick' lines at sensible points around the value's range.

  CGContextSaveGState(ctx);
  CGContextAddPath(ctx, fill_path);
  CGContextClip(ctx);
  CGContextSetLineWidth(ctx, 1);
  CGContextSetRGBStrokeColor(ctx, 1, 1, 1, .7);

  double min_tick, max_tick, tick_delta;
  l.tick_values(min_tick, max_tick, tick_delta);

  for (double tick = min_tick; tick < max_tick; tick += tick_delta)
    {
      CGFloat y = l.convert_to_si(tick);
      y = y * ym + y0;
      y = floor(y) + 0.5;
      CGPoint lines[2];
      lines[0] = CGPointMake(_chart_rect.origin.x, y);
      lines[1] = CGPointMake(_chart_rect.origin.x + _chart_rect.size.width, y);
      CGContextStrokeLineSegments(ctx, lines, 2);
    }

  CGContextRestoreGState(ctx);

  // Draw data line

  switch (l.color)
    {
    case RED:
      CGContextSetRGBStrokeColor(ctx, 1, 0, 0.3, 1);
      break;
    case GREEN:
      CGContextSetRGBStrokeColor(ctx, 0, 0.8, 0.2, 1);
      break;
    case BLUE:
      CGContextSetRGBStrokeColor(ctx, 0, 0.8, 1, 1);
      break;
    case ORANGE:
      CGContextSetRGBStrokeColor(ctx, 1, 0.5, 0, 1);
      break;
    }

  CGContextAddPath(ctx, path);
  CGContextSetLineWidth(ctx, 1.5);
  CGContextStrokePath(ctx);

  CGContextRestoreGState(ctx);

  CGPathRelease(fill_path);
  CGPathRelease(path);
}

void
chart::draw_lap_markers(CGContextRef ctx)
{
  std::vector<CGPoint> lines;
  lines.reserve(2 * _activity.laps().size());

  CGFloat x_scale = 1. / (_max_dist - _min_dist);
  CGFloat x0 = (_chart_rect.origin.x
		- _min_dist * x_scale * _chart_rect.size.width);
  CGFloat xm = x_scale * _chart_rect.size.width;

  CGFloat total_dist = 0;
  for (size_t i = 0; i < _activity.laps().size(); i++)
    {
      CGFloat x = total_dist * xm + x0;
      x = floor(x) + 0.5;
      lines.push_back(CGPointMake(x, _chart_rect.origin.y));
      lines.push_back(CGPointMake(x, _chart_rect.origin.y
				  + _chart_rect.size.height));
      total_dist += _activity.laps()[i].distance;
    }

  CGContextSaveGState(ctx);
  CGContextSetLineWidth(ctx, 1);
  CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 0.2);
  CGContextStrokeLineSegments(ctx, &lines[0], lines.size());
  CGContextRestoreGState(ctx);
}

} // namespace gps
} // namespace act
