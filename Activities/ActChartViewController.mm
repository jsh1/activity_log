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

#import "ActChartViewController.h"

#import "ActActivityViewController.h"
#import "ActCollapsibleView.h"
#import "ActColor.h"
#import "ActViewLayout.h"
#import "ActWindowController.h"

#import "act-format.h"

#define MIN_WIDTH 500
#define MIN_HEIGHT 200
#define SMOOTHING 5

#define MIN_TICK_GAP 30
#define KEY_TEXT_WIDTH 60
#define LABEL_FONT "Lucida Grande"
#define LABEL_FONT_SIZE 9
#define LABEL_HEIGHT 14

#define BOX_WIDTH 80
#define BOX_HEIGHT 20
#define BOX_FONT_SIZE 12
#define BOX_INSET 8

@interface ActChartViewController ()
- (void)updateChart;
- (void)updateTitle;
@end

enum ChartFields
{
  CHART_PACE_MI,
  CHART_PACE_KM,
  CHART_SPEED_MI,
  CHART_SPEED_KM,
  CHART_SPEED_VVO2MAX,
  CHART_HR_BPM,
  CHART_HR_HRR,
  CHART_HR_MAX,
  CHART_ALT_FT,
  CHART_ALT_M,
  CHART_CADENCE,
  CHART_STRIDE_LENGTH,
  CHART_VERT_OSC,
  CHART_STANCE_TIME,
  CHART_STANCE_RATIO,
  CHART_FIELD_COUNT,
};

enum ChartFieldMasks
{
  CHART_PACE_MI_MASK = 1U << CHART_PACE_MI,
  CHART_PACE_KM_MASK = 1U << CHART_PACE_KM,
  CHART_SPEED_MI_MASK = 1U << CHART_SPEED_MI,
  CHART_SPEED_KM_MASK = 1U << CHART_SPEED_KM,
  CHART_SPEED_VVO2MAX_MASK = 1U << CHART_SPEED_VVO2MAX,

  CHART_HR_BPM_MASK = 1U << CHART_HR_BPM,
  CHART_HR_HRR_MASK = 1U << CHART_HR_HRR,
  CHART_HR_MAX_MASK = 1U << CHART_HR_MAX,

  CHART_ALT_FT_MASK = 1U << CHART_ALT_FT,
  CHART_ALT_M_MASK = 1U << CHART_ALT_M,

  CHART_CADENCE_MASK = 1U << CHART_CADENCE,
  CHART_STRIDE_LENGTH_MASK = 1U << CHART_STRIDE_LENGTH,
  CHART_VERT_OSC_MASK = 1U << CHART_VERT_OSC,
  CHART_STANCE_TIME_MASK = 1U << CHART_STANCE_TIME,
  CHART_STANCE_RATIO_MASK = 1U << CHART_STANCE_RATIO,

  CHART_SPEED_ANY_MASK = CHART_PACE_MI_MASK
			 | CHART_PACE_KM_MASK
			 | CHART_SPEED_MI_MASK
			 | CHART_SPEED_KM_MASK
			 | CHART_SPEED_VVO2MAX_MASK,
  CHART_HR_ANY_MASK = CHART_HR_BPM_MASK
		      | CHART_HR_HRR_MASK
		      | CHART_HR_MAX_MASK,
  CHART_ALT_ANY_MASK = CHART_ALT_FT_MASK
		       | CHART_ALT_M_MASK,
  CHART_CADENCE_ANY_MASK = CHART_CADENCE_MASK
			   | CHART_STRIDE_LENGTH_MASK,
  CHART_STANCE_ANY_MASK = CHART_STANCE_TIME_MASK
			  | CHART_STANCE_RATIO_MASK,
};

namespace chart_view {

class chart : public act::gps::chart
{
public:
  chart(const act::gps::activity &a, act::gps::chart::x_axis_type x_axis);

  virtual void draw();

  virtual CGRect current_time_rect() const;

private:
  void draw_line(const line &l, const x_axis_state &xs, CGFloat tx);

  void draw_lap_markers(const x_axis_state &xs);

  void draw_current_time();
};

chart::chart(const act::gps::activity &a, act::gps::chart::x_axis_type x_axis)
: act::gps::chart(a, x_axis)
{
}

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

  CGFloat fill_rgb[3], stroke_rgb[3];

  switch (l.color)
    {
    case line_color::red:
      fill_rgb[0] = 1;
      fill_rgb[1] = .5;
      fill_rgb[2] = .5;
      stroke_rgb[0] = 1;
      stroke_rgb[1] = 0;
      stroke_rgb[2] = 0.3;
      break;
    case line_color::green:
      fill_rgb[0] = .75;
      fill_rgb[1] = 1;
      fill_rgb[2] = .75;
      stroke_rgb[0] = 0;
      stroke_rgb[1] = 0.6;
      stroke_rgb[2] = 0.2;
      break;
    case line_color::blue:
      fill_rgb[0] = .5;
      fill_rgb[1] = .5;
      fill_rgb[2] = 1;
      stroke_rgb[0] = 0;
      stroke_rgb[1] = 0.2;
      stroke_rgb[2] = 1;
      break;
    case line_color::orange:
      fill_rgb[0] = stroke_rgb[0] = 1;
      fill_rgb[1] = stroke_rgb[1] = .5;
      fill_rgb[2] = stroke_rgb[2] = 0;
      break;
    case line_color::yellow:
      fill_rgb[0] = stroke_rgb[0] = 1;
      fill_rgb[1] = stroke_rgb[1] = 1;
      fill_rgb[2] = stroke_rgb[2] = 0;
      break;
    case line_color::magenta:
      fill_rgb[0] = stroke_rgb[0] = 1;
      fill_rgb[1] = stroke_rgb[1] = 0;
      fill_rgb[2] = stroke_rgb[2] = 1;
      break;
    case line_color::teal:
      fill_rgb[0] = stroke_rgb[0] = 0;
      fill_rgb[1] = stroke_rgb[1] = .5;
      fill_rgb[2] = stroke_rgb[2] = .5;
      break;
    case line_color::steel_blue:
      fill_rgb[0] = stroke_rgb[0] = 70/255.;
      fill_rgb[1] = stroke_rgb[1] = 130/255.;
      fill_rgb[2] = stroke_rgb[2] = 180/255.;
      break;
    case line_color::tomato:
      fill_rgb[0] = stroke_rgb[0] = 1;
      fill_rgb[1] = stroke_rgb[1] = 99/255.;
      fill_rgb[2] = stroke_rgb[2] = 71/255.;
      break;
    case line_color::gray:
      fill_rgb[0] = stroke_rgb[0] = .6;
      fill_rgb[1] = stroke_rgb[1] = .6;
      fill_rgb[2] = stroke_rgb[2] = .6;
      break;
    }

  {
    NSBezierPath *path = [[NSBezierPath alloc] init];

    bool first_pt = true;
    CGFloat first_x = 0, first_y = 0;
    CGFloat last_x = 0, last_y = 0;

    // basic smoothing to avoid rendering multiple data points per pixel

    double skipped_total = 0, skipped_count = 0;

    act::gps::activity::point::field_fn dist_fn = xs.field_fn;
    act::gps::activity::point::field_fn value_fn
      = act::gps::activity::point::field_function(l.field);
  
    for (size_t li = 0; li < _activity.laps().size(); li++)
      {
	const act::gps::activity::lap &lap = _activity.laps()[li];
	const act::gps::activity::point *track = &lap.track[0];

	for (size_t ti = 0; ti < lap.track.size(); ti++)
	  {
	    const act::gps::activity::point &p = track[ti];
	    double dist = dist_fn(&p);
	    double value = value_fn(&p);
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
		    [path moveToPoint:NSMakePoint(x, y)];
		    first_x = x, first_y = y, first_pt = false;
		  }
		else
		  [path lineToPoint:NSMakePoint(x, y)];
		last_x = x, last_y = y;
	      }
	    else
	      skipped_total += value, skipped_count += 1;
	  }
      }

    // Fill under the line

    if (l.flags & FILL_BG)
      {
	NSBezierPath *fill_path = [path copy];
	CGFloat y1 = _chart_rect.origin.y + _chart_rect.size.height;
	[fill_path lineToPoint:NSMakePoint(last_x, y1)];
	[fill_path lineToPoint:NSMakePoint(first_x, y1)];
	[fill_path lineToPoint:NSMakePoint(first_x, first_y)];
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

	[[NSColor colorWithCalibratedRed:r green:g blue:b alpha:a] setFill];
	[fill_path fill];

	[fill_path release];
      }

    // Draw stroked line

    if (!(l.flags & NO_STROKE))
      {
	[[NSColor colorWithCalibratedRed:stroke_rgb[0] green:stroke_rgb[1]
	  blue:stroke_rgb[2] alpha:1] setStroke];
	[path setLineWidth:1.75];
	[path setLineJoinStyle:NSBevelLineJoinStyle];
	[path stroke];
      }

    [path release];
  }

  {
    // Draw 'tick' lines at sensible points around the value's range.

    static NSDictionary *left_attrs, *right_attrs;

    if (left_attrs == nil)
      {
	NSMutableParagraphStyle *rightStyle
	= [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[rightStyle setAlignment:NSRightTextAlignment];

	left_attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
		      [NSFont fontWithName:@"Helvetica Neue Medium"
		       size:LABEL_FONT_SIZE],
		      NSFontAttributeName,
		      [ActColor controlTextColor],
		      NSForegroundColorAttributeName,
		      nil];
	right_attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
		       [NSFont fontWithName:@"Helvetica Neue Medium"
			size:LABEL_FONT_SIZE],
		       NSFontAttributeName,
		       [ActColor controlTextColor],
		       NSForegroundColorAttributeName,
		       rightStyle,
		       NSParagraphStyleAttributeName,
		       nil];
      }

    NSBezierPath *path = [[NSBezierPath alloc] init];

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
	    [path moveToPoint:NSMakePoint(llx, y)];
	    [path lineToPoint:NSMakePoint(urx, y)];
	  }

	std::string s;
	l.format_tick(s, tick, value);

	[[NSString stringWithUTF8String:s.c_str()]
	 drawInRect:NSMakeRect(tx, y - (LABEL_HEIGHT + 2), KEY_TEXT_WIDTH, LABEL_HEIGHT)
	 withAttributes:!(l.flags & RIGHT_TICKS) ? left_attrs : right_attrs];

	ly = y;
      }

    if (l.flags & TICK_LINES)
      {
	static const CGFloat dash[] = {4, 2};
	[path setLineDash:dash count:2 phase:0];
	[path setLineWidth:1];
	[[NSColor colorWithCalibratedRed:stroke_rgb[0]
	  green:stroke_rgb[1] blue:stroke_rgb[2] alpha:.25] setStroke];
	[path stroke];
      }

    [path release];
  }
}

void
chart::draw_lap_markers(const x_axis_state &xs)
{
  NSBezierPath *path = [NSBezierPath bezierPath];

  double total_dist = (x_axis() == x_axis_type::distance
		       ? 0 : _activity.start_time());

  CGFloat lly = _chart_rect.origin.y;
  CGFloat ury = lly + _chart_rect.size.height;

  NSRect highlightRect = NSZeroRect;
  highlightRect.origin.y = lly;
  highlightRect.size.height = ury - lly;

  for (size_t i = 0; true; i++)
    {
      CGFloat x = total_dist * xs.xm + xs.xc;
      x = floor(x) + 0.5;

      [path moveToPoint:NSMakePoint(x, lly)];
      [path lineToPoint:NSMakePoint(x, ury)];

      if (_selected_lap >= 0 && _selected_lap == i)
	highlightRect.origin.x = x;
      else if (_selected_lap >= 0 && _selected_lap == i - 1)
	highlightRect.size.width = x - highlightRect.origin.x;

      if (!(i < _activity.laps().size()))
	break;

      if (x_axis() == x_axis_type::distance)
	total_dist += _activity.laps()[i].total_distance;
      else
	total_dist = (_activity.laps()[i].start_time
		      + _activity.laps()[i].total_duration);
    }

  static const CGFloat dash[] = {4, 2};
  [path setLineDash:dash count:2 phase:0];
  [path setLineWidth:1];

  [[NSColor colorWithDeviceWhite:0 alpha:.1] setStroke];
  [path stroke];

  if (highlightRect.size.width > 0)
    {
      [[NSColor colorWithCalibratedRed:.5 green:.5 blue:.8 alpha:.2] setFill];
      NSRectFillUsingOperation(highlightRect, NSCompositePlusDarker);
    }
}

void
chart::draw_current_time()
{
  if (_current_time < 0)
    return;

  act::gps::activity::point pt;
  if (!_activity.point_at_time(_activity.start_time() + _current_time, pt))
    return;

  x_axis_state xs(*this, x_axis());

  double t = xs.field_fn(&pt);
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

  [[ActColor controlBackgroundColor] setFill];
  [NSBezierPath fillRect:NSRectFromCGRect(boxR)];
  [[ActColor controlTextColor] set];
  [NSBezierPath fillRect:NSRectFromCGRect(lineR)];
  [NSBezierPath strokeRect:NSInsetRect(NSRectFromCGRect(boxR), .5, .5)];

  NSRect textR = NSInsetRect(boxR, BOX_INSET, 0);

  NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
			 [NSFont fontWithName:@"Helvetica Neue Bold"
			  size:BOX_FONT_SIZE],
			 NSFontAttributeName,
			 [ActColor controlDetailTextColor],
			 NSForegroundColorAttributeName,
			 nil];

  std::string buf;
  act::format_duration(buf, round(pt.timestamp - _activity.start_time()));
  buf.append("\n");
  act::format_distance(buf, pt.distance, act::unit_type::unknown);
  buf.append("\n");

  for (const auto &it : _lines)
    {
      double value = act::gps::activity::point::field_function(it.field)(&pt);

      switch (it.field)
	{
	case act::gps::activity::point_field::speed:
	  act::format_pace(buf, value, act::unit_type::unknown);
	  break;

	case act::gps::activity::point_field::heart_rate: {
	  act::unit_type unit = act::unit_type::beats_per_minute;
	  if (it.conversion
	      == act::gps::chart::value_conversion::heartrate_bpm_pmax)
	    unit = act::unit_type::percent_hr_max;
	  else if (it.conversion
		   == act::gps::chart::value_conversion::heartrate_bpm_hrr)
	    unit = act::unit_type::percent_hr_reserve;
	  act::format_heart_rate(buf, value, unit);
	  break; }

	case act::gps::activity::point_field::altitude: {
	  act::unit_type unit = act::unit_type::metres;
	  if (it.conversion
	      == act::gps::chart::value_conversion::distance_m_ft)
	    unit = act::unit_type::feet;
	  act::format_distance(buf, value, unit);
	  break; }

	case act::gps::activity::point_field::cadence:
	  act::format_cadence(buf, value, act::unit_type::steps_per_minute);
	  break;

	case act::gps::activity::point_field::vertical_oscillation:
	  act::format_distance(buf, value, act::unit_type::millimetres);
	  break;

	case act::gps::activity::point_field::stance_time:
	  act::format_duration(buf, value);
	  break;

	case act::gps::activity::point_field::stance_ratio:
	  act::format_fraction(buf, value);
	  break;

	case act::gps::activity::point_field::stride_length:
	  act::format_distance(buf, value, act::unit_type::metres);
	  break;

	default:
	  act::format_number(buf, value);
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

  act::gps::activity::point pt;
  if (!_activity.point_at_time(_activity.start_time() + _current_time, pt))
    return CGRectNull;

  x_axis_state xs(*this, x_axis());

  double t = xs.field_fn(&pt);
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

} // namespace chart_view

@implementation ActChartViewController

+ (NSString *)viewNibName
{
  return @"ActChartView";
}

- (id)initWithController:(ActWindowController *)controller
    options:(NSDictionary *)opts
{
  self = [super initWithController:controller options:opts];
  if (self == nil)
    return nil;

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:_controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedLapIndexDidChange:)
   name:ActSelectedLapIndexDidChange object:_controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(currentTimeWillChange:)
   name:ActCurrentTimeWillChange object:_controller];
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(currentTimeDidChange:)
   name:ActCurrentTimeDidChange object:_controller];

  _fieldMask = CHART_PACE_MI_MASK | CHART_ALT_M_MASK;

  return self;
}

- (void)viewDidLoad
{
  [_configMenu setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];

  [_removeButton setEnabled:[self identifierSuffix] != nil];

  [self updateTitle];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (act::gps::chart *)chart
{
  return _chart.get();
}

- (void)_updateChart
{
  if (_chart)
    {
      _chart.reset();
      [_chartView setNeedsDisplay:YES];
    }

  const act::activity *a = [_controller selectedActivity];
  if (a == nullptr)
    return;

  const act::gps::activity *gps_a = a->gps_data();
  if (gps_a == nullptr)
    return;

  if (!_smoothed_data
      || _smoothed_data->start_time() != gps_a->start_time()
      || _smoothed_data->total_distance() != gps_a->total_distance()
      || _smoothed_data->total_duration() != gps_a->total_duration())
    {
      _smoothed_data.reset(new act::gps::activity);
      _smoothed_data->smooth(*gps_a, SMOOTHING);
    }

  bool draw_pace = (_fieldMask & CHART_SPEED_ANY_MASK) && gps_a->has_speed();
  bool draw_hr = (_fieldMask & CHART_HR_ANY_MASK) && gps_a->has_heart_rate();
  bool draw_altitude = (_fieldMask & CHART_ALT_ANY_MASK) && gps_a->has_altitude();
  bool draw_cadence = (_fieldMask & CHART_CADENCE_MASK) && gps_a->has_cadence();
  bool draw_stride_len = (_fieldMask & CHART_STRIDE_LENGTH_MASK) && gps_a->has_cadence();
  bool draw_vert_osc = (_fieldMask & CHART_VERT_OSC_MASK) && gps_a->has_dynamics();
  bool draw_stance = (_fieldMask & CHART_STANCE_ANY_MASK) && gps_a->has_dynamics();

  if (!(draw_pace || draw_hr || draw_altitude || draw_cadence
	|| draw_stride_len || draw_vert_osc || draw_stance))
    return;

  _chart.reset(new chart_view::chart(*_smoothed_data.get(),
				   act::gps::chart::x_axis_type::distance));

  if (draw_hr)
    {
      double bot = !draw_pace ? -0.05 : -.55;

      auto conv = act::gps::chart::value_conversion::identity;
      if (_fieldMask & CHART_HR_HRR_MASK)
	conv = act::gps::chart::value_conversion::heartrate_bpm_hrr;
      else if (_fieldMask & CHART_HR_MAX_MASK)
	conv = act::gps::chart::value_conversion::heartrate_bpm_pmax;

      _chart->add_line(act::gps::activity::point_field::heart_rate, conv,
		       act::gps::chart::line_color::orange,
		       act::gps::chart::FILL_BG
		       | act::gps::chart::OPAQUE_BG
		       | act::gps::chart::TICK_LINES, bot, 1.05);
    }

  if (draw_pace)
    {
      double top = !draw_hr ? 1.05 : 1.35;

      auto conv = act::gps::chart::value_conversion::identity;
      if (_fieldMask & CHART_PACE_MI_MASK)
	conv = act::gps::chart::value_conversion::speed_ms_pace_mi;
      else if (_fieldMask & CHART_PACE_KM_MASK)
	conv = act::gps::chart::value_conversion::speed_ms_pace_km;
      else if (_fieldMask & CHART_SPEED_MI_MASK)
	conv = act::gps::chart::value_conversion::speed_ms_mph;
      else if (_fieldMask & CHART_SPEED_KM_MASK)
	conv = act::gps::chart::value_conversion::speed_ms_kph;
      else if (_fieldMask & CHART_SPEED_VVO2MAX_MASK)
	conv = act::gps::chart::value_conversion::speed_ms_vvo2max;

      _chart->add_line(act::gps::activity::point_field::speed, conv,
		       act::gps::chart::line_color::blue,
		       act::gps::chart::FILL_BG
		       | act::gps::chart::OPAQUE_BG
		       | act::gps::chart::TICK_LINES, -0.05, top);
    }

  if (draw_altitude)
    {
      auto conv = act::gps::chart::value_conversion::identity;
      if (_fieldMask & CHART_ALT_FT_MASK)
	conv = act::gps::chart::value_conversion::distance_m_ft;

      uint32_t flags = act::gps::chart::FILL_BG;
      auto color = act::gps::chart::line_color::green;

      if (draw_pace || draw_hr)
	{
	  flags |= act::gps::chart::NO_STROKE | act::gps::chart::RIGHT_TICKS;
	  color = act::gps::chart::line_color::gray;
	}
      else
	flags |= act::gps::chart::TICK_LINES;

      _chart->add_line(act::gps::activity::point_field::altitude, conv,
		       color, flags, -0.05, 1.05);
    }

  if (draw_cadence)
    {
      _chart->add_line(act::gps::activity::point_field::cadence,
		       act::gps::chart::value_conversion::identity,
		       act::gps::chart::line_color::tomato,
		       act::gps::chart::FILL_BG | act::gps::chart::TICK_LINES,
		       -0.05, 1.05);
    }

  if (draw_stride_len)
    {
      _chart->add_line(act::gps::activity::point_field::stride_length,
		       act::gps::chart::value_conversion::identity,
		       act::gps::chart::line_color::green,
		       act::gps::chart::FILL_BG | act::gps::chart::TICK_LINES,
		       -0.05, 1.05);
    }

  if (draw_vert_osc)
    {
      _chart->add_line(act::gps::activity::point_field::vertical_oscillation,
		       act::gps::chart::value_conversion::distance_m_cm,
		       act::gps::chart::line_color::teal,
		       act::gps::chart::FILL_BG | act::gps::chart::TICK_LINES,
		       -0.05, 1.05);
    }

  if (draw_stance)
    {
      auto field = (_fieldMask & CHART_STANCE_TIME_MASK
		    ? act::gps::activity::point_field::stance_time
		    : act::gps::activity::point_field::stance_ratio);

      _chart->add_line(field, act::gps::chart::value_conversion::time_s_ms,
		       act::gps::chart::line_color::yellow,
		       act::gps::chart::FILL_BG | act::gps::chart::TICK_LINES,
		       -0.05, 1.05);
    }

  _chart->set_chart_rect(NSRectToCGRect([_chartView bounds]));
  _chart->set_selected_lap([_controller selectedLapIndex]);
  _chart->update_values();

  [_chartView setNeedsDisplay:YES];
}

- (void)updateChart
{
  bool had_chart = (bool)_chart;

  [self _updateChart];

  bool has_chart = (bool)_chart;

  if (had_chart != has_chart)
    [[_chartView superview] subviewNeedsLayout:_chartView];
}

- (void)updateTitle
{
  NSMutableString *str = nil;

  for (NSInteger i = 0; i < CHART_FIELD_COUNT; i++)
    {
      if (_fieldMask & (1U << i))
	{
	  if (str == nil)
	    str = [[NSMutableString alloc] init];
	  else
	    [str appendString:@" + "];

	  NSString *type = nil;
	  switch (i)
	    {
	    case CHART_PACE_MI:
	      type = @"Pace (min/mi)";
	      break;
	    case CHART_PACE_KM:
	      type = @"Pace (min/km)";
	      break;
	    case CHART_SPEED_MI:
	      type = @"Speed (mph)";
	      break;
	    case CHART_SPEED_KM:
	      type = @"Speed (km/h)";
	      break;
	    case CHART_SPEED_VVO2MAX:
	      type = @"Pace (%vVO2max)";
	      break;
	    case CHART_HR_BPM:
	      type = @"Heart Rate (BPM)";
	      break;
	    case CHART_HR_HRR:
	      type = @"Heart Rate (%HRR)";
	      break;
	    case CHART_HR_MAX:
	      type = @"Heart Rate (%MAX)";
	      break;
	    case CHART_ALT_FT:
	      type = @"Altitude (ft)";
	      break;
	    case CHART_ALT_M:
	      type = @"Altitude (m)";
	      break;
	    case CHART_CADENCE:
	      type = @"Cadence (spm)";
	      break;
	    case CHART_STRIDE_LENGTH:
	      type = @"Stride Length (m)";
	      break;
	    case CHART_VERT_OSC:
	      type = @"Vertical Oscillation (cm)";
	      break;
	    case CHART_STANCE_TIME:
	      type = @"Stance Time (ms)";
	      break;
	    case CHART_STANCE_RATIO:
	      type = @"Stance Ratio (%)";
	      break;
	    }
	  if (type != nil)
	    [str appendString:type];
	}
    }

  [(ActCollapsibleView *)[self view] setTitle:str != nil ? str : @"Chart"];

  [str release];
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  [self updateChart];
}

- (void)selectedLapIndexDidChange:(NSNotification *)note
{
  if (_chart)
    {
      _chart->set_selected_lap([_controller selectedLapIndex]);
      [_chartView setNeedsDisplay:YES];
    }
}

- (void)currentTimeWillChange:(NSNotification *)note
{
  if (_chart)
    {
      CGRect dirtyR = _chart->current_time_rect();
      [_chartView setNeedsDisplayInRect:NSRectFromCGRect(dirtyR)];
    }
}

- (void)currentTimeDidChange:(NSNotification *)note
{
  if (_chart)
    {
      _chart->set_current_time([_controller currentTime]);

      CGRect dirtyR = _chart->current_time_rect();
      [_chartView setNeedsDisplayInRect:NSRectFromCGRect(dirtyR)];
    }
}

- (IBAction)configMenuAction:(id)sender
{
  uint32_t bit = 1U << [sender tag];
  uint32_t mask = bit;

  if (mask & CHART_SPEED_ANY_MASK)
    mask |= CHART_SPEED_ANY_MASK;
  else if (mask & CHART_HR_ANY_MASK)
    mask |= CHART_HR_ANY_MASK;
  else if (mask & CHART_ALT_ANY_MASK)
    mask |= CHART_ALT_ANY_MASK;
  else if (mask & CHART_STANCE_ANY_MASK)
    mask |= CHART_STANCE_ANY_MASK;

  _fieldMask = _fieldMask & ~mask;

  if (![sender state])
    _fieldMask |= bit;

  [self updateChart];
  [self updateTitle];
}

- (void)popUpConfigMenuForView:(NSView *)view
{
  [_configMenu popUpMenuPositioningItem:[_configMenu itemAtIndex:0]
   atLocation:[view bounds].origin inView:view];
}

- (IBAction)buttonAction:(id)sender
{
  if (sender == _addButton)
    {
      [(ActActivityViewController *)[self superviewController]
       addSubviewControllerWithClass:[self class] after:self];
    }
  else if (sender == _removeButton)
    {
      [(ActActivityViewController *)[self superviewController]
       removeSubviewController:self];
    }
}

- (NSDictionary *)savedViewState
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
	  [NSNumber numberWithUnsignedInt:_fieldMask],
	  @"fieldMask",
	  nil];
}

- (void)applySavedViewState:(NSDictionary *)state
{
  if (NSNumber *obj = [state objectForKey:@"fieldMask"])
    {
      _fieldMask = [obj unsignedIntValue];
      [self updateChart];
      [self updateTitle];
    }
}

// ActLayoutDelegate methods

- (CGFloat)heightOfView:(NSView *)view forWidth:(CGFloat)width
{
  if (view == _chartView)
    {
      if ([self chart])
	return 150;
      else
	return 0;
    }
  else
    return [view heightForWidth:width];
}

- (void)layoutSubviewsOfView:(NSView *)view
{
}

// NSMenuDelegate methods

- (void)menuNeedsUpdate:(NSMenu*)menu
{
  if (menu == _configMenu)
    {
      uint32_t enableMask = 0;

      if (const act::activity *a = [_controller selectedActivity])
	{
	  if (const act::gps::activity *gps_a = a->gps_data())
	    {
	      if (gps_a->has_speed())
		enableMask |= CHART_SPEED_ANY_MASK;
	      if (gps_a->has_heart_rate())
		enableMask |= CHART_HR_ANY_MASK;
	      if (gps_a->has_altitude())
		enableMask |= CHART_ALT_ANY_MASK;
	      if (gps_a->has_cadence())
		enableMask |= CHART_CADENCE_ANY_MASK;
	      if (gps_a->has_dynamics())
		enableMask |= CHART_VERT_OSC_MASK | CHART_STANCE_ANY_MASK;
	    }
	}

      for (NSMenuItem *item in [menu itemArray])
	{
	  if ([item action] == @selector(configMenuAction:))
	    {
	      uint32_t bit = 1U << [item tag];
	      [item setState:(_fieldMask & bit) ? NSOnState : NSOffState];
	      [item setEnabled:(_fieldMask & bit) ? YES : NO];
	    }
	}	      
    }
}

- (void)mouseExited:(NSEvent *)e
{
  [_controller setCurrentTime:-1];
}

- (void)mouseMoved:(NSEvent *)e
{
  if (_chart)
    {
      NSPoint p = [_chartView convertPoint:[e locationInWindow] fromView:nil];

      act::gps::activity::point pt;
      if (_chart->point_at_x(p.x, pt))
	{
	  double t = pt.timestamp - _chart->get_activity().start_time();
	  [_controller setCurrentTime:t];
	}
    }
}

@end


@implementation ActChartView

- (void)updateTrackingAreas
{
  NSRect bounds = [self bounds];

  if (_trackingArea == nil
      || !NSEqualRects(bounds, [_trackingArea rect]))
    {
      [self removeTrackingArea:_trackingArea];
      _trackingArea = [[NSTrackingArea alloc] initWithRect:bounds
		       options:(NSTrackingMouseEnteredAndExited
				| NSTrackingMouseMoved
				| NSTrackingActiveInKeyWindow)
		       owner:_controller userInfo:nil];
      [self addTrackingArea:_trackingArea];
      [_trackingArea release];
    }
}

- (void)drawRect:(NSRect)r
{
  [[ActColor controlBackgroundColor] setFill];
  [NSBezierPath fillRect:r];

  if (act::gps::chart *chart = [_controller chart])
    {
      chart->set_chart_rect(NSRectToCGRect([self bounds]));
      chart->draw();
    }
}

- (BOOL)isOpaque
{
  return YES;
}

- (BOOL)isFlipped
{
  return YES;
}

@end


@implementation ActChartViewConfigLabel

- (void)mouseDown:(NSEvent *)e
{
  [_controller popUpConfigMenuForView:self];
}

@end
