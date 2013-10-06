// -*- c-style: gnu -*-

#include "act-gps-chart.h"

#include "act-config.h"
#include "act-format.h"

#include <math.h>

#define MILES_PER_METER 0.000621371192
#define FEET_PER_METER 3.2808399

#define SECS_PER_MILE(x) ((1. /  (x)) * (1. / MILES_PER_METER))
#define MILES_PER_SEC(x) (1. / ((x) * MILES_PER_METER))

#define MAX_TICKS 4
#define MIN_TICKS 2

#define KEY_TEXT_WIDTH 60

#define LABEL_FONT "Lucida Grande"
#define LABEL_SIZE 9

namespace act {
namespace gps {

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
    case value_conversion::SPEED_MS_PACE:
      return x > 0 ? SECS_PER_MILE(x) : 0;
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
    case value_conversion::SPEED_MS_PACE:
      return x > 0 ? MILES_PER_SEC(x) : 0;
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

  switch (conversion)
    {
    case value_conversion::HEARTRATE_BPM_HRR:
    case value_conversion::HEARTRATE_BPM_PMAX:
      tick_delta = 5;
      break;
    case value_conversion::SPEED_MS_PACE:
      tick_delta = 30;
      break;
    case value_conversion::DISTANCE_M_FT:
      tick_delta = 100;
      break;
    default:
      tick_delta = 1;
    }

  while ((tick_max - tick_min) / tick_delta > MAX_TICKS)
    tick_delta = tick_delta * 2;
  while ((tick_max - tick_min) / tick_delta < MIN_TICKS)
    tick_delta = tick_delta * .5;

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
      if (conversion == value_conversion::SPEED_MS_PACE)
	format_pace(s, value, unit_type::seconds_per_mile);
      else
	format_speed(s, value, unit_type::miles_per_hour);
    }
  else if (field == &activity::point::heart_rate)
    {
      format_number(s, tick);
      if (conversion == value_conversion::HEARTRATE_BPM_HRR)
	s.append(" %HRR");
      else if (conversion == value_conversion::HEARTRATE_BPM_PMAX)
	s.append(" % max");
      else
	s.append(" bpm");
    }
  else
    {
      format_number(s, tick);
    }
}

chart::chart(const activity &a, x_axis_type xa)
: _activity(a),
  _x_axis(xa),
  _x_axis_field(_x_axis == x_axis_type::DISTANCE
		? &activity::point::distance : &activity::point::time),
  _chart_rect(CGRectNull),
  _selected_lap(-1)
{
  double mean, sdev;
  a.get_range(_x_axis_field, _min_x_value, _max_x_value, mean, sdev);
}

void
chart::add_line(double activity::point:: *field, value_conversion conv,
		line_color color, bool fill_bg, double min_ratio,
		double max_ratio)
{

  _lines.push_back(line(field, conv, color, fill_bg, min_ratio, max_ratio));
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
}

void
chart::set_selected_lap(int idx)
{
  _selected_lap = idx;
}

void
chart::draw(CGContextRef ctx)
{
  draw_background(ctx);

  for (size_t i = 0; i < _lines.size(); i++)
    draw_line(ctx, _lines[i], i * KEY_TEXT_WIDTH);

  draw_lap_markers(ctx);
}

void
chart::draw_background(CGContextRef ctx)
{
#if 0
  CGContextSaveGState(ctx);
  CGContextSetLineWidth(ctx, 1);
  CGContextSetGrayFillColor(ctx, .98, 1);
  CGContextFillRect(ctx, _chart_rect);
//  CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.2);
//  CGContextStrokeRect(ctx, CGRectInset(_chart_rect, .5, .5));
  CGContextRestoreGState(ctx);
#endif
}

void
chart::draw_line(CGContextRef ctx, const line &l, CGFloat tx)
{
  /* x' = (x - min_v) * v_scale * chart_w + chart_x
        = x * v_scale * chart_w - min_v * v_scale * chart_w + chart_x
	v_scale = 1 / (max_v - min_v). */

  CGFloat x_scale = 1. / (_max_x_value - _min_x_value);
  CGFloat x0 = (_chart_rect.origin.x
		- _min_x_value * x_scale * _chart_rect.size.width);
  CGFloat xm = x_scale * _chart_rect.size.width;

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
	  double dist = p.*_x_axis_field;
	  double value = p.*(l.field);
	  if (dist == 0 || value == 0)
	    continue;
	  CGFloat x = dist * xm + x0;
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

  // Fill gradient under the line

  if (l.fill_bg)
    {
      CGContextSaveGState(ctx);

      switch (l.color)
	{
	case line_color::RED:
	  CGContextSetRGBFillColor(ctx, 1, .5, .5, .4);
	  break;
	case line_color::GREEN:
	  CGContextSetRGBFillColor(ctx, .75, 1, .75, .4);
	  break;
	case line_color::BLUE:
	  CGContextSetRGBFillColor(ctx, .5, .75, 1, .4);
	  break;
	case line_color::ORANGE:
	  CGContextSetRGBFillColor(ctx, 1, .5, 0, .4);
	  break;
	case line_color::GRAY:
	  CGContextSetRGBFillColor(ctx, .75, .75, .75, .4);
	  break;
	}

      CGContextAddPath(ctx, fill_path);
      CGContextFillPath(ctx);

      CGContextRestoreGState(ctx);
    }

  // Draw data line

  CGContextSaveGState(ctx);

  switch (l.color)
    {
    case line_color::RED:
      CGContextSetRGBStrokeColor(ctx, 1, 0, 0.3, 1);
      break;
    case line_color::GREEN:
      CGContextSetRGBStrokeColor(ctx, 0, 0.6, 0.2, 1);
      break;
    case line_color::BLUE:
      CGContextSetRGBStrokeColor(ctx, 0, 0.2, 1, 1);
      break;
    case line_color::ORANGE:
      CGContextSetRGBStrokeColor(ctx, 1, 0.5, 0, 1);
      break;
    case line_color::GRAY:
      CGContextSetRGBStrokeColor(ctx, 0.6, 0.6, 0.6, 1);
      break;
    }

  CGContextAddPath(ctx, path);
  CGContextSetLineWidth(ctx, 1.75);
  CGContextSetLineJoin(ctx, kCGLineJoinBevel);
  CGContextStrokePath(ctx);

  CGContextRestoreGState(ctx);

  // Draw 'tick' lines at sensible points around the value's range.

  CGContextSaveGState(ctx);

  CGContextSetLineWidth(ctx, 1);
  CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.1);

  CGContextSelectFont(ctx, LABEL_FONT, LABEL_SIZE, kCGEncodingMacRoman);
  CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
  CGContextSetTextDrawingMode(ctx, kCGTextFill);
  CGContextSetGrayFillColor(ctx, 0.1, 1);

  for (double tick = l.tick_min; tick < l.tick_max; tick += l.tick_delta)
    {
      double value = l.convert_to_si(tick);
      CGFloat y = value;
      y = y * ym + y0;
      y = floor(y) + 0.5;
      CGPoint lines[2];
      lines[0] = CGPointMake(_chart_rect.origin.x, y);
      lines[1] = CGPointMake(_chart_rect.origin.x + _chart_rect.size.width, y);
      CGContextStrokeLineSegments(ctx, lines, 2);

      std::string s;
      l.format_tick(s, tick, value);

      CGContextShowTextAtPoint(ctx, _chart_rect.origin.x + tx + 2,
			       y + 2, s.c_str(), s.size());
    }

  CGContextRestoreGState(ctx);

  CGContextRestoreGState(ctx);

  CGPathRelease(fill_path);
  CGPathRelease(path);
}

void
chart::draw_lap_markers(CGContextRef ctx)
{
  std::vector<CGPoint> lines;
  lines.reserve(2 * (_activity.laps().size() + 1));

  CGFloat x_scale = 1. / (_max_x_value - _min_x_value);
  CGFloat x0 = (_chart_rect.origin.x
		- _min_x_value * x_scale * _chart_rect.size.width);
  CGFloat xm = x_scale * _chart_rect.size.width;

  CGFloat total_dist = _x_axis == x_axis_type::DISTANCE ? 0 : _activity.time();

  for (size_t i = 0; true; i++)
    {
      CGFloat x = total_dist * xm + x0;
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

} // namespace gps
} // namespace act
