// -*- c-style: gnu -*-

#import "ActActivityMapView.h"

#import "ActActivityView.h"
#import "ActMapView.h"
#import "ActTileJSONMapSource.h"

#import "act-gps-activity.h"

#import <algorithm>

#define MAP_HEIGHT 300
#define TOP_BORDER 0
#define BOTTOM_BORDER 0
#define LEFT_BORDER 32
#define RIGHT_BORDER 32

@implementation ActActivityMapView

+ (NSArray *)mapSources
{
  static NSArray *array;

  if (array == nil)
    {
      NSArray *strings = [[NSUserDefaults standardUserDefaults]
			  arrayForKey:@"ActMapSources"];
      if (strings != nil)
	{
	  NSMutableArray *tem = [[NSMutableArray alloc] init];

	  for (NSString *str in strings)
	    {
	      ActMapSource *src = nil;

	      if ([str rangeOfString:@"/"].length == 0)
		src = [ActTileJSONMapSource mapSourceFromResource:str];
	      else
		{
		  NSURL *url = nil;
		  if ([str rangeOfString:@":"].length == 0)
		    url = [NSURL fileURLWithPath:str];
		  else
		    url = [NSURL URLWithString:str];
		  if (url != nil)
		    src = [ActTileJSONMapSource mapSourceFromURL:url];
		}

	      if ([src name] != nil)
		[tem addObject:src];
	    }

	  array = [tem copy];
	  [tem release];
	}
    }

  return array;
}

- (void)setMapSourceAtIndex:(int)idx
{
  NSArray *sources = [[self class] mapSources];
  if (sources == nil)
    return;

  if (idx < 0 || idx >= [sources count])
    return;

  ActMapSource *src = [sources objectAtIndex:idx];
  int src_min = [src minZoom];
  int src_max = [src maxZoom];

  [_mapView setMapSource:src];
  [_zoomSlider setMinValue:src_min];
  [_zoomSlider setMaxValue:src_max];
  [_zoomSlider setNumberOfTickMarks:src_max - src_min + 1];
}

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self == nil)
    return nil;

  NSArray *objects = nil;
  [[NSBundle mainBundle] loadNibNamed:@"ActActivityMapView"
   owner:self topLevelObjects:&objects];

  for (id obj in objects)
    {
      if ([obj isKindOfClass:[NSView class]])
	[self addSubview:obj];

      // FIXME: [auto]release 'obj'?
    }

  for (ActMapSource *src in [[self class] mapSources])
    {
      [_mapSrcButton addItemWithTitle:[src name]];
    }

  [self setMapSourceAtIndex:0];
  [_zoomSlider setIntValue:[_mapView mapZoom]];

  return self;
}

- (void)activityDidChange
{
#if 0
  if (const act::activity *a = [[self activityView] activity])
    {
      if (const act::gps::activity *gps_a = a->gps_data())
	{
	}
    }
#endif
}

- (void)selectedLapDidChange
{
}

- (NSEdgeInsets)edgeInsets
{
  return NSEdgeInsetsMake(TOP_BORDER, LEFT_BORDER,
			  BOTTOM_BORDER, RIGHT_BORDER);
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
  bool empty = true;

  if (const act::activity *a = [[self activityView] activity])
    {
      if (const act::gps::activity *gps_a = a->gps_data())
	{
	  if (gps_a->has_location())
	    empty = false;
	}
    }

  return empty ? 0 : ceil(width * (CGFloat).75);
}

- (void)layoutSubviews
{
  [_mapView setFrame:[self bounds]];
}

- (IBAction)controlAction:(id)sender
{
  if (sender == _mapSrcButton)
    {
      [self setMapSourceAtIndex:[_mapSrcButton indexOfSelectedItem]];
    }
  else if (sender == _zoomSlider)
    {
      [_mapView setMapZoom:[_zoomSlider intValue]];
    }
  else if (sender == _zoomInButton)
    {
      int zoom = [_mapView mapZoom];
      zoom = std::min(zoom + 1, [[_mapView mapSource] maxZoom]);
      [_mapView setMapZoom:zoom];
      [_zoomSlider setIntValue:zoom];
    }
  else if (sender == _zoomOutButton)
    {
      int zoom = [_mapView mapZoom];
      zoom = std::max(zoom - 1, [[_mapView mapSource] minZoom]);
      [_mapView setMapZoom:zoom];
      [_zoomSlider setIntValue:zoom];
    }
}

@end
