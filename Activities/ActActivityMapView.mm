// -*- c-style: gnu -*-

#import "ActActivityMapView.h"

#import "ActActivityViewController.h"
#import "ActMapView.h"
#import "ActTileJSONMapSource.h"

#import "act-gps-activity.h"

#import <algorithm>

@implementation ActActivityMapView

+ (NSArray *)_mapSourcesForKey:(NSString *)key
{
  NSArray *strings = [[NSUserDefaults standardUserDefaults] arrayForKey:key];
  if (strings == nil)
    return nil;

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

  NSArray *ret = [NSArray arrayWithArray:tem];
  [tem release];

  return ret;
}

+ (NSArray *)mapSources
{
  static NSArray *array;

  if (array == nil)
    {
      NSMutableArray *tem = [[NSMutableArray alloc] init];

      if (NSArray *a = [self _mapSourcesForKey:@"ActMapSources"])
	[tem addObjectsFromArray:a];

      if (NSArray *a = [self _mapSourcesForKey:@"ActUserMapSources"])
	[tem addObjectsFromArray:a];

      array = [tem copy];
      [tem release];
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

  [_mapSrcButton selectItemAtIndex:idx];

  [[NSUserDefaults standardUserDefaults]
   setObject:[src name] forKey:@"ActDefaultMapSource"];
}

- (void)mapSourceDidFinishLoading:(NSNotification *)note
{
  if (--_pendingSources > 0)
    return;

  [_mapSrcButton removeAllItems];

  NSString *default_name = [[NSUserDefaults standardUserDefaults]
			    stringForKey:@"ActDefaultMapSource"];
  NSInteger default_idx = 0;
  NSInteger idx = 0;

  for (ActMapSource *src in [[self class] mapSources])
    {
      NSString *name = [src name];
      [_mapSrcButton addItemWithTitle:name];
      if ([name isEqualToString:default_name])
	default_idx = idx;
      idx++;
    }

  [self setMapSourceAtIndex:default_idx];
}

- (void)awakeFromNib
{
  for (ActMapSource *src in [[self class] mapSources])
    {
      if ([src isLoading])
	_pendingSources++;
    }

  if (_pendingSources > 0)
    {
      [[NSNotificationCenter defaultCenter] addObserver:self
       selector:@selector(mapSourceDidFinishLoading:)
       name:ActMapSourceDidFinishLoading object:nil];
    }
  else
    [self mapSourceDidFinishLoading:nil];

  [_zoomSlider setIntValue:[_mapView mapZoom]];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [super dealloc];
}

- (CGSize)preferredSize
{
  return CGSizeMake(600, 350);
}

- (CGSize)minimumSize
{
  return CGSizeMake(100, 100);
}

- (void)_updateDisplayedRegion
{
  const act::activity *a = [[self controller] activity];
  if (!a)
    return;

  const act::gps::activity *gps_a = a->gps_data();
  if (!gps_a || !gps_a->has_location())
    return;

  [_mapView displayRegion:gps_a->region()];

  // FIXME: need a notification/KVO for this?

  [_zoomSlider setIntValue:[_mapView mapZoom]];
}

- (void)activityDidChange
{
  [self _updateDisplayedRegion];
}

- (void)selectedLapDidChange
{
  const act::activity *a = [[self controller] activity];

  if (a != nullptr && a->gps_data() != nullptr)
    [_mapView setNeedsDisplay:YES];
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
  else if (sender == _centerButton)
    {
      [self _updateDisplayedRegion];
    }
}

- (void)mapView:(ActMapView *)view drawOverlayRect:(NSRect)r
    mapBottomLeft:(const act::location &)loc_ll
    topRight:(const act::location &)loc_ur
{
  const act::activity *a = [[self controller] activity];
  if (!a)
    return;

  const act::gps::activity *gps_a = a->gps_data();
  if (!gps_a || !gps_a->has_location())
    return;

  CGContextRef ctx =
    (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];

  NSRect bounds = [view bounds];

  CGContextSaveGState(ctx);

  CGContextSetRGBStrokeColor(ctx, 0, 0.2, 1, .75);
  CGContextSetLineWidth(ctx, 3);

  double xa = bounds.size.width / (loc_ur.longitude - loc_ll.longitude);
  double xb = bounds.origin.x - loc_ll.longitude * xa;

  double ya = bounds.size.height / (loc_ur.latitude - loc_ll.latitude);
  double yb = bounds.origin.y - loc_ll.latitude * ya;

  bool in_subpath = false;
  CGPoint cp = CGPointZero;

  int current_lap = 0;
  int selected_lap = [[self controller] selectedLapIndex];

  for (const auto &lap : gps_a->laps())
    {
      if (current_lap == selected_lap)
	{
	  CGContextStrokePath(ctx);
	  CGContextSaveGState(ctx);
	  CGContextSetRGBStrokeColor(ctx, 1, 0, 0.3, 1);
	  CGContextBeginPath(ctx);
	  CGContextMoveToPoint(ctx, cp.x, cp.y);
	}
	
      for (const auto &p : lap.track)
	{
	  if (p.location.longitude == 0 && p.location.latitude == 0)
	    continue;

	  CGFloat px = p.location.longitude * xa + xb;
	  CGFloat py = p.location.latitude * ya + yb;

	  if (!in_subpath)
	    {
	      CGContextBeginPath(ctx);
	      CGContextMoveToPoint(ctx, px, py);
	      in_subpath = true;
	    }
	  else
	    {
	      CGContextAddLineToPoint(ctx, px, py);
	      cp = CGPointMake(px, py);
	    }
	}

      if (current_lap == selected_lap)
	{
	  CGContextStrokePath(ctx);
	  CGContextRestoreGState(ctx);
	  CGContextBeginPath(ctx);
	  CGContextMoveToPoint(ctx, cp.x, cp.y);
	}

      current_lap++;
    }

  CGContextStrokePath(ctx);

  CGContextRestoreGState(ctx);
}

@end
