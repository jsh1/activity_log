// -*- c-style: gnu -*-

#import "ActActivityChartView.h"

#import "ActActivityViewController.h"

#define MIN_WIDTH 500
#define MIN_HEIGHT 200
#define SMOOTHING 10

@implementation ActActivityChartView

- (CGFloat)minSize
{
  return 160;
}

- (void)_updateChart
{
  if (_chart)
    {
      _chart.reset();
      [self setNeedsDisplay:YES];
    }

  const act::activity *a = [[self controller] activity];
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

  if ([_segmentedControl isSelectedForSegment:2] && gps_a->has_altitude())
    {
      _chart->add_line(&act::gps::activity::point::altitude,
		       act::gps::chart::value_conversion::DISTANCE_M_FT,
		       act::gps::chart::line_color::GRAY, true, -0.05, 2);
    }

  if ([_segmentedControl isSelectedForSegment:0] && gps_a->has_speed())
    {
      _chart->add_line(&act::gps::activity::point::speed,
		       act::gps::chart::value_conversion::SPEED_MS_PACE,
		       act::gps::chart::line_color::BLUE, false, -0.05, 1.05);
    }

  if ([_segmentedControl isSelectedForSegment:1] && gps_a->has_heart_rate())
    {
      _chart->add_line(&act::gps::activity::point::heart_rate,
		       act::gps::chart::value_conversion::IDENTITY,
		       act::gps::chart::line_color::RED, false, -0.05, 1.05);
    }

  _chart->set_chart_rect(NSRectToCGRect([self bounds]));
  _chart->set_selected_lap([[self controller] selectedLapIndex]);
  _chart->update_values();

  [self setNeedsDisplay:YES];
}

- (void)activityDidChange
{
  bool has_pace = false, has_hr = false, has_altitude = false;

  if (const act::activity *a = [[self controller] activity])
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

- (void)selectedLapDidChange
{
  if (_chart)
    {
      _chart->set_selected_lap([[self controller] selectedLapIndex]);
      [self setNeedsDisplay:YES];
    }
}

- (void)drawRect:(NSRect)r
{
  [self drawBackgroundRect:r];

  if (_chart)
    {
      CGContextRef ctx = (CGContextRef) [[NSGraphicsContext
					  currentContext] graphicsPort];

      CGRect r = CGRectInset(NSRectToCGRect([self bounds]), 2, 2);

      CGContextSaveGState(ctx);
      CGContextClipToRect(ctx, r);

      CGContextTranslateCTM(ctx, 0, r.size.height);
      CGContextScaleCTM(ctx, 1, -1);

      _chart->set_chart_rect(r);
      _chart->draw(ctx);

      CGContextRestoreGState(ctx);
    }
}

- (IBAction)controlAction:(id)sender
{
  if (sender == _segmentedControl)
    {
      [self _updateChart];
    }
}

@end
