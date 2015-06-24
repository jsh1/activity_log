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

#import "Macros.h"

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

#define X_INSET 5
#define Y_INSET 5

#define BG_RADIUS 5

namespace act {
namespace gps {

namespace {

const float chart_hues[] =
{
  [(int)chart::line_color::red] = 0,
  [(int)chart::line_color::green] = 1 / 3.,
  [(int)chart::line_color::blue] = 2 / 3.,
  [(int)chart::line_color::orange] = 1 / 12.,
  [(int)chart::line_color::yellow] = 1 / 6.,
  [(int)chart::line_color::magenta] = 8 / 9.,
  [(int)chart::line_color::teal] = 1 / 2.,
  [(int)chart::line_color::steel_blue] = 23 / 40.,
  [(int)chart::line_color::tomato] = 1 / 40.,
  [(int)chart::line_color::dark_orchid] = 151 / 180.,
};

CGFloat
hue_to_rgb(CGFloat v1, CGFloat v2, CGFloat vh)
{
  if (vh < 0)
    vh += 1;
  if (vh > 1)
    vh -= 1;
  if ((6 * vh) < 1)
    return v1 + (v2 - v1) * vh * 6;
  else if ((vh * 2) < 1)
    return v2;
  else if ((vh * 3) < 2)
    return v1 + (v2 - v1) * (((CGFloat)2/3) - vh) * 6;
  else
    return v1;
}

void
hsl_to_rgb(CGFloat h, CGFloat s, CGFloat l, CGFloat rgb[3])
{
  if (s == 0)
    {
      rgb[2] = rgb[1] = rgb[0] = l;
    }
  else
    {
      CGFloat v1, v2;

      if (l < (CGFloat).5)
	v2 = l * (s + 1);
      else
	v2 = (l + s) - (s * l);
	  
      v1 = 2 * l - v2;

      rgb[0] = hue_to_rgb(v1, v2, h + (CGFloat)(1. / 3));
      rgb[1] = hue_to_rgb(v1, v2, h);
      rgb[2] = hue_to_rgb(v1, v2, h - (CGFloat)(1. / 3));
    }
}

void
hsb_to_rgb(CGFloat h, CGFloat s, CGFloat b, CGFloat rgb[3])
{
  CGFloat l = .5 * b * (2 - s);
  CGFloat s_hsl = l < 1 ? (b * s) / (1 - fabs(2 * l - 1)) : 1;

  hsl_to_rgb(h, s_hsl, l, rgb);
}

CGGradientRef
create_gradient(CGFloat h1, CGFloat s1, CGFloat b1, CGFloat a1,
		CGFloat h2, CGFloat s2, CGFloat b2, CGFloat a2)
{
  CGFloat vec[8];

  hsb_to_rgb(h1, s1, b1, vec+0);
  vec[3] = a1;

  hsb_to_rgb(h2, s2, b2, vec+4);
  vec[7] = a2;

  CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);

#if 0
  /* FIXME: this works in sim but not device!? */
  CGGradientRef grad = CGGradientCreateWithColorComponents(space, vec, nullptr, 2);
#else
  NSArray *colors = @[
    (__bridge id)[UIColor colorWithRed:vec[0] green:vec[1] blue:vec[2] alpha:vec[3]].CGColor,
    (__bridge id)[UIColor colorWithRed:vec[4] green:vec[5] blue:vec[6] alpha:vec[7]].CGColor
  ];
  CGGradientRef grad = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, nullptr);
#endif

  CGColorSpaceRelease(space);

  return grad;
}

} // anonymous namespace

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
  _x_axis(xa)
{
  a.get_range(activity::point_field::elapsed_time, _min_time, _max_time);
  a.get_range(activity::point_field::distance, _min_distance, _max_distance);
}

void
chart::set_bounds(const CGRect &r)
{
  _bounds = r;
  _chart_rect = CGRectInset(r, X_INSET, Y_INSET);
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
  return ((UIFont *)attrs[NSFontAttributeName]).lineHeight;
}

} // anonymous namespace

void
chart::draw()
{
  CGContextRef ctx = UIGraphicsGetCurrentContext();

  CGContextSaveGState(ctx);
  CGContextBeginPath(ctx);
  CGPathRef path = CGPathCreateWithRoundedRect(CGRectInset(bounds(),
    X_INSET, Y_INSET), BG_RADIUS, BG_RADIUS, nullptr);
  CGContextAddPath(ctx, path);
  CGPathRelease(path);
  CGContextClip(ctx);
  
  draw_background();

  x_axis_state xs(*this, x_axis());

  CGFloat tl = bounds().origin.x + X_INSET + 2;

  for (size_t i = 0; i < _lines.size(); i++)
    {
      CGFloat tx = tl;
      tl += KEY_TEXT_WIDTH;

      draw_line(_lines[i], xs, tx);
    }

  if (false)
    draw_lap_markers(xs);

  CGContextRestoreGState(ctx);
}

void
chart::draw_background() const
{
  if (_lines.size() < 1)
    return;

  int color = static_cast<int>(_lines[0].color);
  assert(color >= 0 && color < N_ELEMENTS(chart_hues));

  CGFloat hue = chart_hues[color];

  CGGradientRef grad = create_gradient(hue+.05, .4, 1, 1, hue, .8, .9, 1);

  CGPoint sp = CGPointMake(CGRectGetMidX(bounds()), CGRectGetMinY(bounds()));
  CGPoint ep = CGPointMake(CGRectGetMidX(bounds()), CGRectGetMaxY(bounds()));

  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGContextDrawLinearGradient(ctx, grad, sp, ep, 0);

  CGGradientRelease(grad);
}

void
chart::draw_line(const line &l, const x_axis_state &xs, CGFloat tx) const
{
  /* x' = (x - min_v) * v_scale * chart_w + chart_x
        = x * v_scale * chart_w - min_v * v_scale * chart_w + chart_x
	v_scale = 1 / (max_v - min_v). */

  CGFloat y_scale = 1. / (l.scaled_max_value - l.scaled_min_value);
  CGFloat yc = (chart_rect().origin.y
		- l.scaled_min_value * y_scale * chart_rect().size.height);
  CGFloat ym = y_scale * chart_rect().size.height;

  // flip vertically
  yc = -yc + chart_rect().size.height;
  ym = -ym;

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
	/* This is lame -- adding lines to '[path copy]' modifies 'path'
	   as well!? */

	UIBezierPath *fill_path
	  = [UIBezierPath bezierPathWithCGPath:path.CGPath];

	CGFloat yb = chart_rect().origin.y + chart_rect().size.height;
	[fill_path addLineToPoint:CGPointMake(last_x, yb)];
	[fill_path addLineToPoint:CGPointMake(first_x, yb)];
	[fill_path addLineToPoint:CGPointMake(first_x, first_y)];
	[fill_path closePath];

	assert((int)l.color >= 0 && (int)l.color < N_ELEMENTS(chart_hues));
	CGFloat hue = chart_hues[(int)l.color];

	CGGradientRef grad = create_gradient(hue, .75, 1, 1, hue, 0, 1, .25);

	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSaveGState(ctx);

	CGContextBeginPath(ctx);
	CGContextAddPath(ctx, fill_path.CGPath);
	CGContextClip(ctx);

	CGFloat y0 = CGRectGetMinY(chart_rect());
	CGFloat y1 = CGRectGetMaxY(chart_rect());
	CGPoint sp = CGPointMake(CGRectGetMidX(chart_rect()), MIX(y0, y1, .3));
	CGPoint ep = CGPointMake(CGRectGetMidX(chart_rect()), MIX(y0, y1, 1.3));

	CGContextDrawLinearGradient(ctx, grad, sp, ep,
				    kCGGradientDrawsBeforeStartLocation
				    | kCGGradientDrawsAfterEndLocation);

	CGGradientRelease(grad);

	CGContextRestoreGState(ctx);
      }

    // Draw stroked line

    if (!first_pt)
      {
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSaveGState(ctx);
	CGContextSetShadow(ctx, CGSizeMake(0, 0), 1);

	[[UIColor whiteColor] setStroke];
	path.lineWidth = 2;
	path.lineJoinStyle = kCGLineJoinRound;
	[path stroke];

	CGContextRestoreGState(ctx);
      }
  }

  {
    // Draw 'tick' lines at sensible points around the value's range.

    static NSDictionary *tick_attrs;

    if (tick_attrs == nil)
      {
	NSMutableParagraphStyle *rightStyle
	= [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[rightStyle setAlignment:NSTextAlignmentRight];

	UIFont *label_font
	  = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];

	NSShadow *shadow = [[NSShadow alloc] init];
	shadow.shadowColor = [UIColor blackColor];
	shadow.shadowBlurRadius = 2;
	shadow.shadowOffset = CGSizeMake(0, 0);

	tick_attrs = @{
	  NSFontAttributeName: label_font,
	  NSForegroundColorAttributeName: [UIColor whiteColor],
	    NSShadowAttributeName: shadow,
	};
      }

    UIBezierPath *path = [[UIBezierPath alloc] init];

    CGFloat llx = bounds().origin.x;
    CGFloat urx = llx + bounds().size.width;

    CGFloat lly = chart_rect().origin.y;
    CGFloat ury = lly + chart_rect().size.height;
    CGFloat ly = HUGE_VAL;

    CGFloat label_height = text_attrs_leading(tick_attrs);

    for (double tick = l.tick_min; tick < l.tick_max; tick += l.tick_delta)
      {
	double value = l.convert_to_si(tick);
	CGFloat y = round(value * ym + yc);

	if (y - label_height < lly || y > ury)
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

	[[NSString stringWithUTF8String:s.c_str()]
	 drawInRect:CGRectMake(tx, y - (label_height + 2),
			       KEY_TEXT_WIDTH, label_height)
	 withAttributes:tick_attrs];

	ly = y;
      }

    if (l.flags & TICK_LINES)
      {
	static const CGFloat dash[] = {4, 2};
	[path setLineDash:dash count:2 phase:0];
	path.lineWidth = 1;
	[[UIColor colorWithWhite:1 alpha:.25] setStroke];
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

  CGFloat lly = chart_rect().origin.y;
  CGFloat ury = lly + chart_rect().size.height;

  for (size_t i = 0; true; i++)
    {
      CGFloat x = total_dist * xs.xm + xs.xc;
      x = floor(x) + 0.5;

      [path moveToPoint:CGPointMake(x, lly)];
      [path addLineToPoint:CGPointMake(x, ury)];

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
