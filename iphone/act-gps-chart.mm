/* -*- c-style: gnu -*-

   Copyright (c) 2013-2014 John Harper <jsh@unfactored.org>

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

#import "ActColor.h"

#import <UIKit/UIKit.h>

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

#define BOX_WIDTH 80
#define BOX_HEIGHT 20
#define BOX_FONT_SIZE 12
#define BOX_INSET 8

namespace act {
namespace gps {

chart::x_axis_state::x_axis_state(const chart &chart, x_axis_type type)
{
  switch (type)
    {
    case x_axis_type::distance:
      field = activity::point_field::distance;
      min_value = chart._min_distance;
      max_value = chart._max_distance;
      break;

    case x_axis_type::elapsed_time:
      field = activity::point_field::elapsed_time;
      min_value = chart._min_time;
      max_value = chart._max_time;
      break;
    }

  field_fn = activity::point::field_function(field);

  double x_scale = 1. / (max_value - min_value);

  /* x' = (x - min_v) * v_scale * chart_w + chart_x
        = x * v_scale * chart_w - min_v * v_scale * chart_w + chart_x
	v_scale = 1 / (max_v - min_v). */

  xm = x_scale * chart.chart_rect().size.width;
  xc = (chart.chart_rect().origin.x
	- min_value * x_scale * chart.chart_rect().size.width);
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
      return ((x - cfg.resting_hr())
	      / (cfg.max_hr() - cfg.resting_hr()) * 100.); }
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
    case value_conversion::distance_m_cm:
      return x * 1e2;
    case value_conversion::distance_m_mm:
      return x * 1e3;
    case value_conversion::time_s_ms:
      return x * 1e3;
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
      return (x * (1./100) * (cfg.max_hr() - cfg.resting_hr())
	      + cfg.resting_hr()); }
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
    case value_conversion::distance_m_cm:
      return x * 1e-2;
    case value_conversion::distance_m_mm:
      return x * 1e-3;
    case value_conversion::time_s_ms:
      return x * 1e-3;
    default:
      return x;
    }
}

void
chart::line::update_values(const chart &c)
{
  const activity &a = c._activity;

  float mean, sdev;
  a.get_range(field, min_value, max_value, mean, sdev);

  float border = (max_value - min_value) * .05f;
  min_value -= border;
  max_value += border;

  min_value = mean - 3 * sdev;
  max_value = mean + 3 * sdev;

  if (field == activity::point_field::altitude && max_value - min_value < 100)
    max_value = min_value + 100;

  float f0 = ((0 - min_ratio) * (1 / (max_ratio - min_ratio)));
  float f1 = ((1 - max_ratio) * (1 / (max_ratio - min_ratio)));

  scaled_min_value = min_value + (max_value - min_value) * f0;
  scaled_max_value = max_value + (max_value - min_value) * f1;

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
  switch (field)
    {
    case activity::point_field::altitude:
      format_distance(s, value, conversion == value_conversion::distance_m_ft
		      ? unit_type::feet : unit_type::metres);
      break;

    case activity::point_field::speed:
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
      break;

    case activity::point_field::heart_rate: {
      unit_type unit = unit_type::beats_per_minute;
      if (conversion == value_conversion::heartrate_bpm_hrr)
	unit = unit_type::percent_hr_reserve;
      else if (conversion == value_conversion::heartrate_bpm_pmax)
	unit = unit_type::percent_hr_max;
      format_heart_rate(s, value, unit);
      break; }

    case activity::point_field::cadence:
      format_cadence(s, value, unit_type::steps_per_minute);
      break;

    case activity::point_field::vertical_oscillation:
      format_distance(s, value, unit_type::millimetres);
      break;

    case activity::point_field::stance_time:
      format_duration(s, value);
      break;

    default:
      format_number(s, tick);
    }
}

chart::chart(const activity &a, x_axis_type xa)
: _activity(a),
  _x_axis(xa),
  _selected_lap(-1),
  _current_time(-1)
{
  a.get_range(activity::point_field::elapsed_time, _min_time, _max_time);
  a.get_range(activity::point_field::distance, _min_distance, _max_distance);
}

void
chart::add_line(activity::point_field field, value_conversion conv,
		line_color color, uint32_t flags, float min_ratio,
		float max_ratio)
{
  _lines.push_back(line(field, conv, color, flags, min_ratio, max_ratio));
}

namespace {

inline CGFloat
text_attrs_leading(NSDictionary *attrs)
{
  return ((UIFont *)attrs[NSFontAttributeName]).leading;
}

} // anonymous namespace

void
chart::draw()
{
  x_axis_state xs(*this, x_axis());

  CGFloat tl = _chart_rect.origin.x + 2;
  CGFloat tr = tl + _chart_rect.size.width - 2;

  for (size_t i = 0; i < _lines.size(); i++)
    {
      CGFloat tx;
      if (!(_lines[i].flags & RIGHT_TICKS))
	tx = tl, tl += KEY_TEXT_WIDTH;
      else
	tr -= KEY_TEXT_WIDTH, tx = tr;

      draw_line(_lines[i], xs, tx);
    }

  draw_lap_markers(xs);

  draw_current_time();
}

void
chart::draw_line(const line &l, const x_axis_state &xs, CGFloat tx)
{
  /* x' = (x - min_v) * v_scale * chart_w + chart_x
        = x * v_scale * chart_w - min_v * v_scale * chart_w + chart_x
	v_scale = 1 / (max_v - min_v). */

  CGFloat y_scale = 1. / (l.scaled_max_value - l.scaled_min_value);
  CGFloat yc = (_chart_rect.origin.y
		- l.scaled_min_value * y_scale * _chart_rect.size.height);
  CGFloat ym = y_scale * _chart_rect.size.height;

  // flip vertically
  yc = -yc + _chart_rect.size.height;
  ym = -ym;

  static const CGFloat line_colors[][6] =
    {
      [(int)line_color::red] = {1, .5, .5, 1, 0, .3},
      [(int)line_color::green] = {.75, 1, .75, 0, .6, .2},
      [(int)line_color::blue] = {.5, .5, 1, 0, .2, 1},
      [(int)line_color::orange] = {1, .5, 0, 1, .5, 0},
      [(int)line_color::yellow] = {1, 1, 0, 1, 1, 0},
      [(int)line_color::magenta] = {1, 0, 1, 1, 0, 1},
      [(int)line_color::teal] = {0, .5, .5, 0, .5, .5},
      [(int)line_color::steel_blue] = {70/255., 130/255., 180/255.,
				       70/255., 130/255., 180/255.},
      [(int)line_color::tomato] = {1, 99/255., 71/255., 1, 99/255., 71/255.},
      [(int)line_color::dark_orchid] = {153/255., 50/255., 204/255.,
					153/255., 50/255., 204/255.},
      [(int)line_color::gray] = {.6, .6, .6, .6, .6, .6},
    };

  const CGFloat *fill_rgb = line_colors[(int)l.color];
  const CGFloat *stroke_rgb = line_colors[(int)l.color] + 3;

  {
    UIBezierPath *path = [[UIBezierPath alloc] init];

    bool first_pt = true;
    CGFloat first_x = 0, first_y = 0;
    CGFloat last_x = 0, last_y = 0;

    // basic smoothing to avoid rendering multiple data points per pixel

    double skipped_total = 0, skipped_count = 0;

    activity::point::field_fn dist_fn = xs.field_fn;
    activity::point::field_fn value_fn = activity::point::field_function(l.field);
  
    for (const auto &p : _activity.points())
      {
	double dist = dist_fn(p);
	double value = value_fn(p);
	if (dist == 0 || value == 0)
	  continue;

	CGFloat x = dist * xs.xm + xs.xc;
	if (first_pt || x - last_x >= 1)
	  {
	    if (skipped_count > 0)
	      {
		value = (value + skipped_total) / (skipped_count + 1);
		skipped_total = skipped_count = 0;
	      }
	    CGFloat y = value * ym + yc;
	    if (first_pt)
	      {
		[path moveToPoint:CGPointMake(x, y)];
		first_x = x, first_y = y, first_pt = false;
	      }
	    else
	      [path addLineToPoint:CGPointMake(x, y)];
	    last_x = x, last_y = y;
	  }
	else
	  skipped_total += value, skipped_count += 1;
      }

    // Fill under the line

    if (!first_pt && (l.flags & FILL_BG))
      {
	UIBezierPath *fill_path = [path copy];
	CGFloat y1 = _chart_rect.origin.y + _chart_rect.size.height;
	[fill_path addLineToPoint:CGPointMake(last_x, y1)];
	[fill_path addLineToPoint:CGPointMake(first_x, y1)];
	[fill_path addLineToPoint:CGPointMake(first_x, first_y)];
	[fill_path closePath];

	CGFloat r = fill_rgb[0], g = fill_rgb[1], b = fill_rgb[2], a = .2;

	if (l.flags & OPAQUE_BG)
	  {
	    // D = S + D * (1-Sa)
	    // C' = C*F + (1-F)  [assuming white background]

	    r = r * a + (1 - a);
	    g = g * a + (1 - a);
	    b = b * a + (1 - a);
	    a = 1;
	  }

	[[UIColor colorWithRed:r green:g blue:b alpha:a] setFill];
	[fill_path fill];
      }

    // Draw stroked line

    if (!first_pt && !(l.flags & NO_STROKE))
      {
	[[UIColor colorWithRed:stroke_rgb[0] green:stroke_rgb[1]
	  blue:stroke_rgb[2] alpha:1] setStroke];
	path.lineWidth = 1.75;
	path.lineJoinStyle = kCGLineJoinBevel;
	[path stroke];
      }
  }

  {
    // Draw 'tick' lines at sensible points around the value's range.

    static NSDictionary *left_attrs, *right_attrs;

    if (left_attrs == nil)
      {
	NSMutableParagraphStyle *rightStyle
	= [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[rightStyle setAlignment:NSTextAlignmentRight];

	UIFont *label_font
	  = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];

	left_attrs = @{
	  NSFontAttributeName: label_font,
	  NSForegroundColorAttributeName: [UIColor blackColor]
	};

	right_attrs = @{
	  NSFontAttributeName: label_font,
	  NSForegroundColorAttributeName: [UIColor blackColor],
	  NSParagraphStyleAttributeName: rightStyle
	};
      }

    UIBezierPath *path = [[UIBezierPath alloc] init];

    CGFloat llx = _chart_rect.origin.x;
    CGFloat urx = llx + _chart_rect.size.width;

    CGFloat lly = _chart_rect.origin.y;
    CGFloat ury = lly + _chart_rect.size.height;
    CGFloat ly = HUGE_VAL;

    for (double tick = l.tick_min; tick < l.tick_max; tick += l.tick_delta)
      {
	double value = l.convert_to_si(tick);
	CGFloat y = round(value * ym + yc);

	if (y < lly || y > ury)
	  continue;
	if (fabs(y - ly) < MIN_TICK_GAP)
	  continue;

	if (l.flags & TICK_LINES)
	  {
	    [path moveToPoint:CGPointMake(llx, y)];
	    [path addLineToPoint:CGPointMake(urx, y)];
	  }

	std::string s;
	l.format_tick(s, tick, value);

	NSDictionary *attrs
	  = !(l.flags & RIGHT_TICKS) ? left_attrs : right_attrs;

	CGFloat label_height = text_attrs_leading(attrs);

	[[NSString stringWithUTF8String:s.c_str()]
	 drawInRect:CGRectMake(tx, y - (label_height + 2),
			       KEY_TEXT_WIDTH, label_height)
	 withAttributes:attrs];

	ly = y;
      }

    if (l.flags & TICK_LINES)
      {
	static const CGFloat dash[] = {4, 2};
	[path setLineDash:dash count:2 phase:0];
	path.lineWidth = 1;
	[[UIColor colorWithRed:stroke_rgb[0] green:stroke_rgb[1]
	  blue:stroke_rgb[2] alpha:.25] setStroke];
	[path stroke];
      }
  }
}

void
chart::draw_lap_markers(const x_axis_state &xs)
{
  UIBezierPath *path = [[UIBezierPath alloc] init];

  double total_dist = (x_axis() == x_axis_type::distance
		       ? 0 : _activity.start_time());

  CGFloat lly = _chart_rect.origin.y;
  CGFloat ury = lly + _chart_rect.size.height;

  CGRect highlightRect = CGRectZero;
  highlightRect.origin.y = lly;
  highlightRect.size.height = ury - lly;

  for (size_t i = 0; true; i++)
    {
      CGFloat x = total_dist * xs.xm + xs.xc;
      x = floor(x) + 0.5;

      [path moveToPoint:CGPointMake(x, lly)];
      [path addLineToPoint:CGPointMake(x, ury)];

      if (_selected_lap >= 0 && _selected_lap == i)
	highlightRect.origin.x = x;
      else if (_selected_lap >= 0 && _selected_lap == i - 1)
	highlightRect.size.width = x - highlightRect.origin.x;

      if (!(i < _activity.laps().size()))
	break;

      if (x_axis() == x_axis_type::distance)
	total_dist += _activity.laps()[i].total_distance;
      else
	total_dist = (_activity.laps()[i].start_elapsed_time
		      + _activity.laps()[i].total_elapsed_time);
    }

  static const CGFloat dash[] = {4, 2};
  [path setLineDash:dash count:2 phase:0];
  path.lineWidth = 1;

  [[UIColor colorWithWhite:0 alpha:.1] setStroke];
  [path stroke];

  if (highlightRect.size.width > 0)
    {
      [[UIColor colorWithRed:.5 green:.5 blue:.8 alpha:.2] setFill];
      UIRectFrameUsingBlendMode(highlightRect, kCGBlendModePlusDarker);
    }
}

void
chart::draw_current_time()
{
  if (_current_time < 0)
    return;

  activity::point pt;
  auto elapsed_time = activity::point_field::elapsed_time;
  if (!_activity.point_at(elapsed_time, _current_time, pt))
    return;

  x_axis_state xs(*this, x_axis());

  double t = xs.field_fn(pt);
  if (t < xs.min_value || t > xs.max_value)
    return;

  CGFloat x = round(t * xs.xm + xs.xc);

  CGRect lineR = CGRectMake(x, _chart_rect.origin.y,
			    1, _chart_rect.size.height);

  CGRect boxR;
  boxR.origin.x = x + BOX_INSET;
  boxR.origin.y = _chart_rect.origin.y + BOX_INSET;
  boxR.size.width = BOX_WIDTH;
  boxR.size.height = (2 + _lines.size()) * BOX_HEIGHT;
  if (boxR.origin.x + boxR.size.width + BOX_INSET > CGRectGetMaxX(_chart_rect))
    boxR.origin.x = x - BOX_INSET - boxR.size.width;

  [[UIColor whiteColor] setFill];
  UIRectFill(boxR);
  [[UIColor blackColor] set];
  UIRectFill(lineR);
  [[UIBezierPath bezierPathWithRect:CGRectInset(boxR, .5, .5)] stroke];

  CGRect textR = CGRectInset(boxR, BOX_INSET, 0);

  NSDictionary *attrs = @{
    NSFontAttributeName:
      [UIFont preferredFontForTextStyle:UIFontTextStyleBody],
    NSForegroundColorAttributeName: [UIColor blackColor]
  };

  std::string buf;
  format_duration(buf, round(pt.elapsed_time));
  buf.append("\n");
  format_distance(buf, pt.distance, unit_type::unknown);
  buf.append("\n");

  for (const auto &it : _lines)
    {
      double value = activity::point::field_function(it.field)(pt);

      switch (it.field)
	{
	case activity::point_field::speed:
	  format_pace(buf, value, unit_type::unknown);
	  break;

	case activity::point_field::heart_rate: {
	  unit_type unit = unit_type::beats_per_minute;
	  if (it.conversion == value_conversion::heartrate_bpm_pmax)
	    unit = unit_type::percent_hr_max;
	  else if (it.conversion == value_conversion::heartrate_bpm_hrr)
	    unit = unit_type::percent_hr_reserve;
	  format_heart_rate(buf, value, unit);
	  break; }

	case activity::point_field::altitude: {
	  unit_type unit = unit_type::metres;
	  if (it.conversion == value_conversion::distance_m_ft)
	    unit = unit_type::feet;
	  format_distance(buf, value, unit);
	  break; }

	case activity::point_field::cadence:
	  format_cadence(buf, value, unit_type::steps_per_minute);
	  break;

	case activity::point_field::vertical_oscillation:
	  format_distance(buf, value, unit_type::millimetres);
	  break;

	case activity::point_field::stance_time:
	  format_duration(buf, value);
	  break;

	case activity::point_field::stance_ratio:
	  format_fraction(buf, value);
	  break;

	case activity::point_field::stride_length:
	  format_distance(buf, value, unit_type::metres);
	  break;

	default:
	  format_number(buf, value);
	  break;
	}

      buf.append("\n");
    }

  [[NSString stringWithUTF8String:buf.c_str()]
   drawInRect:textR withAttributes:attrs];
}

CGRect
chart::current_time_rect() const
{
  if (_current_time < 0)
    return CGRectNull;

  activity::point pt;
  auto elapsed_time = activity::point_field::elapsed_time;
  if (!_activity.point_at(elapsed_time, _current_time, pt))
    return CGRectNull;

  x_axis_state xs(*this, x_axis());

  double t = xs.field_fn(pt);
  if (t < xs.min_value || t > xs.max_value)
    return CGRectNull;

  CGFloat x = round(t * xs.xm + xs.xc);

  CGRect lineR = CGRectMake(x, _chart_rect.origin.y,
			    1, _chart_rect.size.height);

  CGRect boxR;
  boxR.origin.x = x + BOX_INSET;
  boxR.origin.y = _chart_rect.origin.y;
  boxR.size.width = BOX_WIDTH;
  boxR.size.height = (2 + _lines.size()) * BOX_HEIGHT;
  if (boxR.origin.x + boxR.size.width + BOX_INSET > CGRectGetMaxX(_chart_rect))
    boxR.origin.x = x - BOX_INSET - boxR.size.width;

  return CGRectUnion(lineR, boxR);
}

bool
chart::point_at_x(double x, activity::point &ret_p) const
{
  x_axis_state x_axis(*this, _x_axis);

  double total_dist = 0;

  for (const auto &lap : _activity.laps())
    {
      double lx0, lx1;

      if (_x_axis == x_axis_type::elapsed_time)
	{
	  lx0 = lap.start_elapsed_time * x_axis.xm + x_axis.xc;
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
      double last_x = 0;

      for (auto it = _activity.lap_begin(lap);
	   it != _activity.points().end(); it++)
	{
	  auto p = *it;

	  double p_value = x_axis.field_fn(p);
	  if (p_value == 0)
	    continue;

	  double p_x = p_value * x_axis.xm + x_axis.xc;

	  if (p_x > x)
	    {
	      if (last_p != nullptr)
		{
		  double f = (p_x - x) / (p_x - last_x);
		  mix(ret_p, *last_p, p, 1-f);
		  return true;
		}
	      else
		return false;
	    }
      
	  last_p = &p;
	  last_x = p_x;
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
