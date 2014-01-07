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

#import "chart-view-chart.h"

#import "act-util.h"

#define MIN_WIDTH 500
#define MIN_HEIGHT 200

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

- (act::chart_view::chart *)chart
{
  return _chart.get();
}

- (void)_updateChart
{
  using namespace act::chart_view;

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
      if (_smoothing > 0)
	{
	  _smoothed_data.reset(new act::gps::activity);
	  _smoothed_data->smooth(*gps_a, _smoothing);
	}
      else if (_smoothed_data)
	_smoothed_data.reset();
    }

  enum line
    {
      line_speed,
      line_hr,
      line_cadence,
      line_stride,
      line_vert_osc,
      line_stance,
      line_altitude,			/* last as it draws on top */
    };

  uint32_t line_mask = 0;
  if ((_fieldMask & CHART_SPEED_ANY_MASK) && gps_a->has_speed())
    line_mask |= 1U << line_speed;
  if ((_fieldMask & CHART_HR_ANY_MASK) && gps_a->has_heart_rate())
    line_mask |= 1U << line_hr;
  if ((_fieldMask & CHART_CADENCE_MASK) && gps_a->has_cadence())
    line_mask |= 1U << line_cadence;
  if ((_fieldMask & CHART_STRIDE_LENGTH_MASK) && gps_a->has_cadence())
    line_mask |= 1U << line_stride;
  if ((_fieldMask & CHART_VERT_OSC_MASK) && gps_a->has_dynamics())
    line_mask |= 1U << line_vert_osc;
  if ((_fieldMask & CHART_STANCE_ANY_MASK) && gps_a->has_dynamics())
    line_mask |= 1U << line_stance;
  if ((_fieldMask & CHART_ALT_ANY_MASK) && gps_a->has_altitude())
    line_mask |= 1U << line_altitude;

  int count = act::popcount(line_mask);
  if (count == 0)
    return;

  const act::gps::activity *data = _smoothed_data.get();
  if (data == nullptr)
    data = gps_a;

  _chart.reset(new chart(*data, x_axis_type::distance));

  int slices = count;
  if (slices > 1 && (line_mask & (1U << line_altitude)))
    slices--;

  int slice_idx = 0;
  double slices_rcp = 1. / slices;

  for (int line_type = line_speed; line_type <= line_altitude; line_type++)
    {
      if (!(line_mask & (1U << line_type)))
	continue;

      double top = (slices - slice_idx) * slices_rcp;
      double bot = top - slices_rcp;

      switch (line_type)
	{
	case line_speed: {
	  auto conv = value_conversion::identity;
	  if (_fieldMask & CHART_PACE_MI_MASK)
	    conv = value_conversion::speed_ms_pace_mi;
	  else if (_fieldMask & CHART_PACE_KM_MASK)
	    conv = value_conversion::speed_ms_pace_km;
	  else if (_fieldMask & CHART_SPEED_MI_MASK)
	    conv = value_conversion::speed_ms_mph;
	  else if (_fieldMask & CHART_SPEED_KM_MASK)
	    conv = value_conversion::speed_ms_kph;
	  else if (_fieldMask & CHART_SPEED_VVO2MAX_MASK)
	    conv = value_conversion::speed_ms_vvo2max;
	  
	  _chart->add_line(act::gps::activity::point_field::speed, conv,
			   line_color::blue, FILL_BG | OPAQUE_BG | TICK_LINES,
			   bot, top);
	  break; }

	case line_hr: {
	  auto conv = value_conversion::identity;
	  if (_fieldMask & CHART_HR_HRR_MASK)
	    conv = value_conversion::heartrate_bpm_hrr;
	  else if (_fieldMask & CHART_HR_MAX_MASK)
	    conv = value_conversion::heartrate_bpm_pmax;

	  _chart->add_line(act::gps::activity::point_field::heart_rate,
			   conv, line_color::orange,
			   FILL_BG | OPAQUE_BG | TICK_LINES,
			   bot, top);
	  break; }

	case line_altitude: {
	  auto conv = value_conversion::identity;
	  if (_fieldMask & CHART_ALT_FT_MASK)
	    conv = value_conversion::distance_m_ft;

	  uint32_t flags = FILL_BG;
	  auto color = line_color::green;

	  if (count > 1)
	    {
	      flags |= NO_STROKE | RIGHT_TICKS;
	      color = line_color::gray;
	    }
	  else
	    flags |= TICK_LINES;

	  _chart->add_line(act::gps::activity::point_field::altitude, conv,
			   color, flags, -0.05, 1.05);
	  break; }

	case line_cadence:
	  _chart->add_line(act::gps::activity::point_field::cadence,
			   value_conversion::identity, line_color::tomato,
			   FILL_BG | OPAQUE_BG | TICK_LINES, bot, top);
	  break;

	case line_stride:
	  _chart->add_line(act::gps::activity::point_field::stride_length,
			   value_conversion::identity, line_color::dark_orchid,
			   FILL_BG | OPAQUE_BG | TICK_LINES, bot, top);
	  break;

	case line_vert_osc:
	  _chart->add_line(act::gps::activity::point_field::vertical_oscillation,
			   value_conversion::distance_m_cm, line_color::teal,
			   FILL_BG | OPAQUE_BG | TICK_LINES, bot, top);
	  break;

	case line_stance: {
	  auto field = (_fieldMask & CHART_STANCE_TIME_MASK
			? act::gps::activity::point_field::stance_time
			: act::gps::activity::point_field::stance_ratio);

	  _chart->add_line(field, value_conversion::time_s_ms,
			   line_color::steel_blue, FILL_BG | OPAQUE_BG
			   | TICK_LINES, bot, top);
	  break; }
	}

      if (line_type != line_altitude)
	slice_idx++;
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

- (IBAction)smoothingAction:(id)sender
{
  int tag = [sender tag];

  if (_smoothing != tag)
    {
      _smoothing = tag;
      _smoothed_data.reset();
      [self _updateChart];
    }
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
  return @{
    @"fieldMask": @(_fieldMask),
    @"smoothing": @(_smoothing)
  };
}

- (void)applySavedViewState:(NSDictionary *)state
{
  if (NSNumber *obj = [state objectForKey:@"fieldMask"])
    _fieldMask = [obj unsignedIntValue];

  if (NSNumber *obj = [state objectForKey:@"smoothing"])
    _smoothing = [obj intValue];

  [self updateChart];
  [self updateTitle];
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
	  else if ([item action] == @selector(smoothingAction:))
	    {
	      [item setState:[item tag] == _smoothing];
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

  if (act::chart_view::chart *chart = [_controller chart])
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
