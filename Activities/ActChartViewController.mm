// -*- c-style: gnu -*-

#import "ActChartViewController.h"

#import "ActCollapsibleView.h"
#import "ActColor.h"
#import "ActViewLayout.h"
#import "ActWindowController.h"

#define MIN_WIDTH 500
#define MIN_HEIGHT 200
#define SMOOTHING 5

@interface ActChartViewController ()
- (void)_updateTitle;
@end

enum ChartFields
{
  CHART_PACE_MI,
  CHART_PACE_KM,
  CHART_SPEED_MI,
  CHART_SPEED_KM,
  CHART_HR_BPM,
  CHART_HR_HRR,
  CHART_HR_MAX,
  CHART_ALT_FT,
  CHART_ALT_M,
  CHART_FIELD_COUNT,
};

enum ChartFieldMasks
{
  CHART_PACE_MI_MASK = 1U << CHART_PACE_MI,
  CHART_PACE_KM_MASK = 1U << CHART_PACE_KM,
  CHART_SPEED_MI_MASK = 1U << CHART_SPEED_MI,
  CHART_SPEED_KM_MASK = 1U << CHART_SPEED_KM,

  CHART_HR_BPM_MASK = 1U << CHART_HR_BPM,
  CHART_HR_HRR_MASK = 1U << CHART_HR_HRR,
  CHART_HR_MAX_MASK = 1U << CHART_HR_MAX,

  CHART_ALT_FT_MASK = 1U << CHART_ALT_FT,
  CHART_ALT_M_MASK = 1U << CHART_ALT_M,

  CHART_SPEED_ANY_MASK = CHART_PACE_MI_MASK
			 | CHART_PACE_KM_MASK
			 | CHART_SPEED_MI_MASK
			 | CHART_SPEED_KM_MASK,
  CHART_HR_ANY_MASK = CHART_HR_BPM_MASK
		      | CHART_HR_HRR_MASK
		      | CHART_HR_MAX_MASK,
  CHART_ALT_ANY_MASK = CHART_ALT_FT_MASK
		       | CHART_ALT_M_MASK,
};

@implementation ActChartViewController

+ (NSString *)viewNibName
{
  return @"ActChartView";
}

- (void)viewDidLoad
{
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:_controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedLapIndexDidChange:)
   name:ActSelectedLapIndexDidChange object:_controller];

  [_configMenu setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];

  _fieldMask = CHART_PACE_MI_MASK;

  [self _updateTitle];
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

- (void)__updateChart
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
      || _smoothed_data->time() != gps_a->time()
      || _smoothed_data->distance() != gps_a->distance()
      || _smoothed_data->duration() != gps_a->duration())
    {
      _smoothed_data.reset(new act::gps::activity);
      _smoothed_data->smooth(*gps_a, SMOOTHING);
    }

  bool draw_pace = (_fieldMask & CHART_SPEED_ANY_MASK) && gps_a->has_speed();
  bool draw_hr = (_fieldMask & CHART_HR_ANY_MASK) && gps_a->has_heart_rate();
  bool draw_altitude = (_fieldMask & CHART_ALT_ANY_MASK) && gps_a->has_altitude();

  if (!(draw_pace || draw_hr || draw_altitude))
    return;

  _chart.reset(new act::gps::chart(*_smoothed_data.get(),
				   act::gps::chart::x_axis_type::DISTANCE));

  if (draw_hr)
    {
      double bot = !draw_pace ? -0.05 : -.55;

      auto conv = act::gps::chart::value_conversion::IDENTITY;
      if (_fieldMask & CHART_HR_HRR_MASK)
	conv = act::gps::chart::value_conversion::HEARTRATE_BPM_HRR;
      else if (_fieldMask & CHART_HR_MAX_MASK)
	conv = act::gps::chart::value_conversion::HEARTRATE_BPM_PMAX;

      _chart->add_line(&act::gps::activity::point::heart_rate, conv,
		       act::gps::chart::line_color::ORANGE,
		       act::gps::chart::FILL_BG
		       | act::gps::chart::OPAQUE_BG
		       | act::gps::chart::TICK_LINES, bot, 1.05);
    }

  if (draw_pace)
    {
      double bot = !draw_altitude ? -0.05 : -.25;
      double top = !draw_hr ? 1.05 : 1.35;

      auto conv = act::gps::chart::value_conversion::IDENTITY;
      if (_fieldMask & CHART_PACE_MI_MASK)
	conv = act::gps::chart::value_conversion::SPEED_MS_PACE_MI;
      else if (_fieldMask & CHART_PACE_KM_MASK)
	conv = act::gps::chart::value_conversion::SPEED_MS_PACE_KM;
      else if (_fieldMask & CHART_SPEED_MI_MASK)
	conv = act::gps::chart::value_conversion::SPEED_MS_MPH;
      else if (_fieldMask & CHART_SPEED_KM_MASK)
	conv = act::gps::chart::value_conversion::SPEED_MS_KPH;

      _chart->add_line(&act::gps::activity::point::speed, conv,
		       act::gps::chart::line_color::BLUE,
		       act::gps::chart::FILL_BG
		       | act::gps::chart::OPAQUE_BG
		       | act::gps::chart::TICK_LINES, bot, top);
    }

  if (draw_altitude)
    {

      auto conv = act::gps::chart::value_conversion::IDENTITY;
      if (_fieldMask & CHART_ALT_FT_MASK)
	conv = act::gps::chart::value_conversion::DISTANCE_M_FT;

      _chart->add_line(&act::gps::activity::point::altitude, conv,
		       act::gps::chart::line_color::GREEN,
		       act::gps::chart::FILL_BG, -0.05, 2);
    }

  _chart->set_chart_rect(NSRectToCGRect([_chartView bounds]));
  _chart->set_selected_lap([_controller selectedLapIndex]);
  _chart->update_values();

  [_chartView setNeedsDisplay:YES];
}

- (void)_updateChart
{
  bool had_chart = (bool)_chart;

  [self __updateChart];

  bool has_chart = (bool)_chart;

  if (had_chart != has_chart)
    [[_chartView superview] subviewNeedsLayout:_chartView];
}

- (void)_updateTitle
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
  [self _updateChart];
}

- (void)selectedLapIndexDidChange:(NSNotification *)note
{
  if (_chart)
    {
      _chart->set_selected_lap([_controller selectedLapIndex]);
      [_chartView setNeedsDisplay:YES];
    }
}

- (IBAction)controlAction:(id)sender
{
  if (sender == _configButton)
    {
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

  _fieldMask = _fieldMask & ~mask;

  if (![sender state])
    _fieldMask |= bit;

  [self _updateChart];
  [self _updateTitle];
}

- (void)popUpConfigMenuForView:(NSView *)view
{
  [_configMenu popUpMenuPositioningItem:[_configMenu itemAtIndex:0]
   atLocation:[view bounds].origin inView:view];
}

- (IBAction)toggleChartField:(id)sender
{
  _fieldMask ^= 1U << [sender tag];

  [self _updateChart];
  [self _updateTitle];
}

- (BOOL)chartFieldIsShown:(NSInteger)field
{
  return (_fieldMask & (1U << field)) != 0;
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
      [self _updateChart];
      [self _updateTitle];
    }
}

// ActLayoutDelegate methods

- (CGFloat)heightOfView:(NSView *)view forWidth:(CGFloat)width
{
  if (view == _chartView)
    {
      if ([self chart])
	return 160;
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

@end


@implementation ActChartView

- (void)drawRect:(NSRect)r
{
  [[ActColor controlBackgroundColor] setFill];
  [NSBezierPath fillRect:r];

  if (act::gps::chart *chart = [_controller chart])
    {
      CGContextRef ctx = (CGContextRef) [[NSGraphicsContext
					  currentContext] graphicsPort];

      CGRect bounds = NSRectToCGRect([self bounds]);

      CGContextSaveGState(ctx);

      CGContextTranslateCTM(ctx, 0, bounds.size.height);
      CGContextScaleCTM(ctx, 1, -1);

      chart->set_chart_rect(bounds);
      chart->draw(ctx);

      CGContextRestoreGState(ctx);
    }
}

- (BOOL)isOpaque
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
