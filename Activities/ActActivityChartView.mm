// -*- c-style: gnu -*-

#import "ActActivityChartView.h"

#import "ActActivityView.h"

#define CHART_HEIGHT 200
#define TOP_BORDER 0
#define BOTTOM_BORDER 0
#define LEFT_BORDER 32
#define RIGHT_BORDER 32

@implementation ActActivityChartView

+ (ActActivitySubview *)subviewForView:(ActActivityView *)view
{
  NSArray *objects = nil;
  [[NSBundle mainBundle] loadNibNamed:@"ActActivityChartView"
   owner:nil topLevelObjects:&objects];

  // `objects' array can contain our NSApplication as well?

  // FIXME: autorelease contents of `objects'?

  for (id obj in objects)
    {
      if ([obj isKindOfClass:[ActActivityChartView class]])
	{
	  [(ActActivityChartView *)obj setActivityView:view];
	  return obj;
	}
    }

  return nil;
}

- (void)_updateChart
{
  if (_chart)
    {
      _chart.reset();
      [self setNeedsDisplay:YES];
    }

  const act::activity *a = [[self activityView] activity];
  if (a == nullptr)
    return;

  const act::gps::activity *gps_a = a->gps_data();
  if (gps_a == nullptr)
    return;

  _chart.reset(new act::gps::chart(*gps_a, act::gps::chart::x_axis_type::DISTANCE));

  if (gps_a->has_altitude())
    {
      _chart->add_line(&act::gps::activity::point::altitude, false,
		       act::gps::chart::value_conversion::DISTANCE_M_FT,
		       act::gps::chart::line_color::GRAY, true, 0, 2);
    }

  if ([_segmentedControl isSelectedForSegment:0] && gps_a->has_speed())
    {
      _chart->add_line(&act::gps::activity::point::speed, true,
		       act::gps::chart::value_conversion::SPEED_MS_PACE,
		       act::gps::chart::line_color::BLUE, false, 0, 1);
    }

  if ([_segmentedControl isSelectedForSegment:1] && gps_a->has_heart_rate())
    {
      _chart->add_line(&act::gps::activity::point::heart_rate, true,
		       act::gps::chart::value_conversion::IDENTITY,
		       act::gps::chart::line_color::RED, false, 0, 1);
    }

  _chart->set_chart_rect(NSRectToCGRect([self bounds]));
  _chart->set_selected_lap([[self activityView] selectedLapIndex]);
  _chart->update_values();

  [self setNeedsDisplay:YES];
}

- (void)activityDidChange
{
  bool has_pace = false, has_hr = false;

  if (const act::activity *a = [[self activityView] activity])
    {
      if (const act::gps::activity *gps_a = a->gps_data())
	{
	  has_pace = gps_a->has_speed();
	  has_hr = gps_a->has_heart_rate();
	}
    }

  [_segmentedControl setEnabled:has_pace forSegment:0];
  [_segmentedControl setEnabled:has_hr forSegment:1];

  [self _updateChart];
}

- (void)selectedLapDidChange
{
  if (_chart)
    {
      _chart->set_selected_lap([[self activityView] selectedLapIndex]);
      [self setNeedsDisplay:YES];
    }
}

- (NSEdgeInsets)edgeInsets
{
  return NSEdgeInsetsMake(TOP_BORDER, LEFT_BORDER,
			  BOTTOM_BORDER, RIGHT_BORDER);
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
  const act::activity *a = [[self activityView] activity];
  if (a == nullptr)
    return 0;

  const act::gps::activity *gps_a = a->gps_data();
  if (gps_a == nullptr)
    return 0;

  return CHART_HEIGHT;
}

- (void)layoutSubviews
{
  if (_chart)
    {
      CGRect bounds = NSRectToCGRect([self bounds]);

      if (!CGRectEqualToRect(bounds, _chart->chart_rect()))
	{
	  _chart->set_chart_rect(bounds);
	  [self setNeedsDisplay:YES];
	}
    }
}

- (void)drawRect:(NSRect)r
{
  if (_chart)
    {
      CGContextRef ctx = (CGContextRef) [[NSGraphicsContext
					  currentContext] graphicsPort];

      const CGRect &r = _chart->chart_rect();

      CGContextSaveGState(ctx);
      CGContextClipToRect(ctx, r);

      CGContextTranslateCTM(ctx, 0, r.size.height);
      CGContextScaleCTM(ctx, 1, -1);

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
