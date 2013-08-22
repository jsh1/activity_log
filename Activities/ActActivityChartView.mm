// -*- c-style: gnu -*-

#import "ActActivityChartView.h"

#import "ActActivityView.h"

#define CHART_HEIGHT 130
#define CHART_X_BORDER 40
#define CHART_Y_BORDER 10

@implementation ActActivityChartView

@synthesize chartType = _chartType;

+ (ActActivityChartType)defaultChartType
{
  return CHART_NONE;
}

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self == nil)
    return nil;

  _chartType = [[self class] defaultChartType];

  return self;
}

- (void)updateChartRect
{
  if (_chart)
    {
      CGRect bounds = NSRectToCGRect([self bounds]);

      bounds = CGRectInset(bounds, CHART_X_BORDER, CHART_Y_BORDER);

      if (!CGRectEqualToRect(bounds, _chart->chart_rect()))
	{
	  _chart->set_chart_rect(NSRectToCGRect(bounds));
	  [self setNeedsDisplay:YES];
	}
    }
}

- (void)activityDidChange
{
  if (_chart)
    {
      _chart.reset();
      [self setNeedsDisplay:YES];
    }

  if (const act::activity *a = [[self activityView] activity])
    {
      if (const act::gps::activity *gps_a = a->gps_data())
	{
	  _chart.reset(new act::gps::chart(*gps_a));

	  if (_chartType == CHART_ALTITUDE && gps_a->has_altitude())
	    {
	      _chart->add_line(&act::gps::activity::point::altitude,
			       false, act::gps::chart::DISTANCE_M_FT,
			       act::gps::chart::GREEN, 0, 1);
	    }

	  if (_chartType == CHART_HEART_RATE && gps_a->has_heart_rate())
	    {
	      _chart->add_line(&act::gps::activity::point::heart_rate,
			       true, act::gps::chart::IDENTITY,
			       act::gps::chart::RED, 0, 1);
	    }

	  if (_chartType == CHART_PACE && gps_a->has_speed())
	    {
	      _chart->add_line(&act::gps::activity::point::speed,
			       true, act::gps::chart::SPEED_MS_PACE,
			       act::gps::chart::ORANGE, 0, 1);
	    }

	  [self updateChartRect];
	}
    }
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
  bool empty = true;

  if (const act::activity *a = [[self activityView] activity])
    {
      if (const act::gps::activity *gps_a = a->gps_data())
	{
	  if (_chartType == CHART_ALTITUDE && gps_a->has_altitude())
	    empty = false;
	  if (_chartType == CHART_HEART_RATE && gps_a->has_heart_rate())
	    empty = false;
	  if (_chartType == CHART_PACE && gps_a->has_speed())
	    empty = false;
	}
    }

  return empty ? 0 : CHART_HEIGHT + CHART_Y_BORDER * 2;
}

- (void)layoutSubviews
{
  [self updateChartRect];
}

- (void)drawRect:(NSRect)r
{
  if (_chart)
    {
      CGContextRef ctx = (CGContextRef) [[NSGraphicsContext
					  currentContext] graphicsPort];

      CGContextSaveGState(ctx);
      CGContextClipToRect(ctx, _chart->chart_rect());

      _chart->draw(ctx);

      CGContextRestoreGState(ctx);
    }
}

- (BOOL)isFlipped
{
  return YES;
}

@end

@implementation ActActivityPaceChartView

+ (ActActivityChartType)defaultChartType
{
  return CHART_PACE;
}

@end

@implementation ActActivityHeartRateChartView

+ (ActActivityChartType)defaultChartType
{
  return CHART_HEART_RATE;
}

@end

@implementation ActActivityAltitudeChartView

+ (ActActivityChartType)defaultChartType
{
  return CHART_ALTITUDE;
}

@end
