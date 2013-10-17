// -*- c-style: gnu -*-

#import "ActChartViewController.h"

#import "ActColor.h"
#import "ActWindowController.h"

#define MIN_WIDTH 500
#define MIN_HEIGHT 200
#define SMOOTHING 5

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
      || _smoothed_data->time() != gps_a->time()
      || _smoothed_data->distance() != gps_a->distance()
      || _smoothed_data->duration() != gps_a->duration())
    {
      _smoothed_data.reset(new act::gps::activity);
      _smoothed_data->smooth(*gps_a, SMOOTHING);
    }

  _chart.reset(new act::gps::chart(*_smoothed_data.get(),
				   act::gps::chart::x_axis_type::DISTANCE));

  bool draw_altitude = [_segmentedControl isSelectedForSegment:2] && gps_a->has_altitude();
  bool draw_hr = [_segmentedControl isSelectedForSegment:1] && gps_a->has_heart_rate();
  bool draw_pace = [_segmentedControl isSelectedForSegment:0] && gps_a->has_speed();

  if (draw_hr)
    {
      double bot = !draw_pace ? -0.05 : -.55;

      _chart->add_line(&act::gps::activity::point::heart_rate,
		       act::gps::chart::value_conversion::HEARTRATE_BPM_HRR,
		       act::gps::chart::line_color::ORANGE,
		       act::gps::chart::FILL_BG
		       | act::gps::chart::OPAQUE_BG
		       | act::gps::chart::TICK_LINES, bot, 1.05);
    }

  if (draw_pace)
    {
      double bot = !draw_altitude ? -0.05 : -.25;
      double top = !draw_hr ? 1.05 : 1.35;

      _chart->add_line(&act::gps::activity::point::speed,
		       act::gps::chart::value_conversion::SPEED_MS_PACE,
		       act::gps::chart::line_color::BLUE,
		       act::gps::chart::FILL_BG
		       | act::gps::chart::OPAQUE_BG
		       | act::gps::chart::TICK_LINES, bot, top);
    }

  if (draw_altitude)
    {
      _chart->add_line(&act::gps::activity::point::altitude,
		       act::gps::chart::value_conversion::DISTANCE_M_FT,
		       act::gps::chart::line_color::GREEN,
		       act::gps::chart::FILL_BG, -0.05, 2);
    }

  _chart->set_chart_rect(NSRectToCGRect([_chartView bounds]));
  _chart->set_selected_lap([_controller selectedLapIndex]);
  _chart->update_values();

  [_chartView setNeedsDisplay:YES];
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  bool has_pace = false, has_hr = false, has_altitude = false;

  if (const act::activity *a = [_controller selectedActivity])
    {
      if (const act::gps::activity *gps_a = a->gps_data())
	{
	  has_pace = gps_a->has_speed();
	  has_hr = gps_a->has_heart_rate();
	  has_altitude = gps_a->has_altitude();
	}
    }

  [_segmentedControl setEnabled:has_pace forSegment:0];
  [_segmentedControl setEnabled:has_hr forSegment:1];
  [_segmentedControl setEnabled:has_altitude forSegment:2];

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
  if (sender == _segmentedControl)
    {
      [self _updateChart];
    }
}

- (IBAction)toggleChartField:(id)sender
{
  NSInteger field = [sender tag];
  BOOL state = [_segmentedControl isSelectedForSegment:field];

  [_segmentedControl setSelected:!state forSegment:field];

  [self _updateChart];
}

- (BOOL)chartFieldIsShown:(NSInteger)field
{
  return [_segmentedControl isSelectedForSegment:field];
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
      CGRect r = CGRectInset(bounds, 2, 2);

      CGContextSaveGState(ctx);
      CGContextClipToRect(ctx, r);

      CGContextTranslateCTM(ctx, 0, r.size.height);
      CGContextScaleCTM(ctx, 1, -1);

      chart->set_chart_rect(r);
      chart->draw(ctx);

      CGContextRestoreGState(ctx);
    }
}

- (BOOL)isOpaque
{
  return YES;
}

@end
