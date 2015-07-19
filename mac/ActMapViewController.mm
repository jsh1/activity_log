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

#import "ActMapViewController.h"

#import "ActCollapsibleView.h"
#import "ActMapView.h"
#import "ActTileJSONMapSource.h"
#import "ActViewLayout.h"
#import "ActWindowController.h"

#import "act-gps-activity.h"

#import <algorithm>

#define SPOT_RADIUS 7

@implementation ActMapViewController
{
  int _pendingSources;
  NSString *_defaultSourceName;

  BOOL _hasCurrentLocation;
  act::location _currentLocation;
}

@synthesize mapView = _mapView;
@synthesize mapSrcButton = _mapSrcButton;
@synthesize zoomSlider = _zoomSlider;
@synthesize zoomInButton = _zoomInButton;
@synthesize zoomOutButton = _zoomOutButton;
@synthesize centerButton = _centerButton;

+ (NSString *)viewNibName
{
  return @"ActMapView";
}

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

      if (src.name != nil)
	[tem addObject:src];
    }

  NSArray *ret = [NSArray arrayWithArray:tem];

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
    }

  return array;
}

- (id)initWithController:(ActWindowController *)controller
    options:(NSDictionary *)opts
{
  self = [super initWithController:controller options:opts];
  if (self == nil)
    return nil;

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:self.controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedLapIndexDidChange:)
   name:ActSelectedLapIndexDidChange object:self.controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(currentTimeWillChange:)
   name:ActCurrentTimeWillChange object:self.controller];
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(currentTimeDidChange:)
   name:ActCurrentTimeDidChange object:self.controller];

  for (ActMapSource *src in [self.class mapSources])
    {
      if (src.loading)
	_pendingSources++;
    }

  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  if (_pendingSources > 0)
    {
      [[NSNotificationCenter defaultCenter] addObserver:self
       selector:@selector(mapSourceDidFinishLoading:)
       name:ActMapSourceDidFinishLoading object:nil];
    }
  else
    [self mapSourceDidFinishLoading:nil];

  ((ActCollapsibleView *)self.view).title = @"Route";

  _zoomSlider.intValue = _mapView.mapZoom;
}

- (void)setMapSourceAtIndex:(int)idx
{
  NSArray *sources = [self.class mapSources];
  if (sources == nil)
    return;

  if (idx < 0 || idx >= sources.count)
    return;

  ActMapSource *src = sources[idx];
  int src_min = src.minZoom;
  int src_max = src.maxZoom;

  _mapView.mapSource = src;
  _zoomSlider.minValue = src_min;
  _zoomSlider.maxValue = src_max;
  _zoomSlider.numberOfTickMarks = src_max - src_min + 1;

  [_mapSrcButton selectItemAtIndex:idx];
}

- (void)setMapSourceByName:(NSString *)name
{
  NSInteger idx = 0;

  for (ActMapSource *src in [self.class mapSources])
    {
      if ([src.name isEqualToString:name])
	{
	  [self setMapSourceAtIndex:idx];
	  break;
	}
	  
      idx++;
    }
}

- (void)mapSourceDidFinishLoading:(NSNotification *)note
{
  if (--_pendingSources > 0)
    return;

  [_mapSrcButton removeAllItems];

  for (ActMapSource *src in [self.class mapSources])
    [_mapSrcButton addItemWithTitle:src.name];

  if (_defaultSourceName != nil)
    {
      [self setMapSourceByName:_defaultSourceName];
      _defaultSourceName = nil;
    }
  else
    [self setMapSourceAtIndex:0];
}

- (NSDictionary *)savedViewState
{
  return @{
    @"mapSourceName": _mapView.mapSource.name,
  };
}

- (void)applySavedViewState:(NSDictionary *)state
{
  if (NSString *name = state[@"mapSourceName"])
    {
      if (_pendingSources > 0 || !self.viewLoaded)
	{
	  _defaultSourceName = [name copy];
	}
      else
	[self setMapSourceByName:name];
    }
}

- (CGFloat)heightOfView:(NSView *)view forWidth:(CGFloat)width
{
  if (view == _mapView)
    {
      const act::activity *a = self.controller.selectedActivity;

      if (a != nullptr && a->gps_data() != nullptr)
	return floor(width * (9./16.));
      else
	return 0;
    }
  else
    return [view heightForWidth:width];
}

- (void)layoutSubviewsOfView:(NSView *)view
{
}

- (void)_updateDisplayedRegion
{
  const act::activity *a = self.controller.selectedActivity;
  if (!a)
    return;

  const act::gps::activity *gps_a = a->gps_data();
  if (!gps_a || !gps_a->has_location())
    return;

  [_mapView displayRegion:gps_a->region()];

  // FIXME: need a notification/KVO for this?

  _zoomSlider.intValue = _mapView.mapZoom;
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  [self _updateDisplayedRegion];
  _mapView.needsDisplay = YES;

  const act::activity *a = self.controller.selectedActivity;
  bool has_map = a != nullptr && a->gps_data() != nullptr;

  _centerButton.enabled = has_map;
}

- (void)selectedLapIndexDidChange:(NSNotification *)note
{
  const act::activity *a = self.controller.selectedActivity;

  if (a != nullptr && a->gps_data() != nullptr)
    _mapView.needsDisplay = YES;
}

- (void)updateCurrentLocation
{
  _hasCurrentLocation = NO;

  double t = self.controller.currentTime;
  if (!(t >= 0))
    return;

  const act::activity *a = self.controller.selectedActivity;
  if (a == nullptr)
    return;

  const act::gps::activity *gps_a = a->gps_data();
  if (gps_a == nullptr)
    return;

  act::gps::activity::point p;
  auto elapsed_time = act::gps::activity::point_field::elapsed_time;
  if (gps_a->point_at(elapsed_time, t, p))
    {
      _currentLocation = p.location;
      _hasCurrentLocation = YES;
    }
}

- (void)setNeedsDisplayForCurrentLocation
{
  if (_hasCurrentLocation)
    {
      NSPoint p = [_mapView pointAtLocation:_currentLocation];
      CGFloat radius = SPOT_RADIUS + 2;
      NSRect r = NSMakeRect(p.x - radius, p.y - radius,
			    radius * 2, radius * 2);
      [_mapView setNeedsDisplayInRect:r];
    }
}

- (void)currentTimeWillChange:(NSNotification *)note
{
  [self setNeedsDisplayForCurrentLocation];
}

- (void)currentTimeDidChange:(NSNotification *)note
{
  [self updateCurrentLocation];
  [self setNeedsDisplayForCurrentLocation];
}

- (IBAction)controlAction:(id)sender
{
  if (sender == _mapSrcButton)
    {
      [self setMapSourceAtIndex:_mapSrcButton.indexOfSelectedItem];
    }
  else if (sender == _zoomSlider)
    {
      _mapView.mapZoom = _zoomSlider.intValue;
    }
  else if (sender == _zoomInButton)
    {
      int zoom = _mapView.mapZoom;
      zoom = std::min(zoom + 1, _mapView.mapSource.maxZoom);
      _mapView.mapZoom = zoom;
      _zoomSlider.intValue = zoom;
    }
  else if (sender == _zoomOutButton)
    {
      int zoom = _mapView.mapZoom;
      zoom = std::max(zoom - 1, _mapView.mapSource.minZoom);
      _mapView.mapZoom = zoom;
      _zoomSlider.intValue = zoom;
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
  const act::activity *a = self.controller.selectedActivity;
  if (!a)
    return;

  const act::gps::activity *gps_a = a->gps_data();
  if (!gps_a || !gps_a->has_location())
    return;

  CGContextRef ctx = [NSGraphicsContext currentContext].CGContext;

  NSRect bounds = view.bounds;

  double xa = bounds.size.width / (loc_ur.longitude - loc_ll.longitude);
  double xb = bounds.origin.x - loc_ll.longitude * xa;

  double ya = bounds.size.height / (loc_ur.latitude - loc_ll.latitude);
  double yb = bounds.origin.y - loc_ll.latitude * ya;

  typedef act::gps::activity::point_vector::const_iterator point_iterator;

  void (^draw_track)(point_iterator begin, point_iterator end,
	CGFloat min_delta_sq) = ^(point_iterator begin, point_iterator end,
	CGFloat min_delta_sq)
    {
      bool in_subpath = false;
      CGFloat last_px = 0, last_py = 0;
      CGFloat sum_px = 0, sum_py = 0;
      CGFloat sum_count = 0;

      for (point_iterator it = begin; it != end; it++)
	{
	  const auto &p = *it;

	  if (!p.location.is_valid())
	    continue;

	  CGFloat px = p.location.longitude * xa + xb;
	  CGFloat py = p.location.latitude * ya + yb;

	  if (!in_subpath)
	    {
	      CGContextBeginPath(ctx);
	      in_subpath = true;
	      CGContextMoveToPoint(ctx, px, py);
	      last_px = px;
	      last_py = py;
	    }
	  else
	    {
	      sum_px += px;
	      sum_py += py;
	      sum_count += 1;

	      px = sum_px * (1 / sum_count);
	      py = sum_py * (1 / sum_count);

	      CGFloat delta_sq = ((last_px - px) * (last_px - px)
				 + (last_py - py) * (last_py - py));
	      if (delta_sq >= min_delta_sq)
		{
		  CGContextAddLineToPoint(ctx, px, py);
		  last_px = px;
		  last_py = py;
		  sum_count = 0;
		  sum_px = sum_py = 0;
		}
	    }
	}

      if (in_subpath)
	{
	  if (sum_count > 0)
	    {
	      CGFloat px = sum_px * (1 / sum_count);
	      CGFloat py = sum_py * (1 / sum_count);
	      CGContextAddLineToPoint(ctx, px, py);
	    }

	  CGContextStrokePath(ctx);
	}
    };

  CGContextSaveGState(ctx);

  CGContextSetRGBStrokeColor(ctx, 0, 0.2, 1, .75);
  CGContextSetLineWidth(ctx, 2);
  CGContextSetLineJoin(ctx, kCGLineJoinRound);

  draw_track(gps_a->points().begin(), gps_a->points().end(), 9);

  int selected_lap = self.controller.selectedLapIndex;

  if (selected_lap >= 0)
    {
      CGContextSetRGBStrokeColor(ctx, 1, 0, 0.3, 1);
      CGContextSetLineWidth(ctx, 5);
      CGContextBeginPath(ctx);

      const auto &lap = gps_a->laps()[selected_lap];

      auto lap_start = gps_a->lap_begin(lap);
      auto lap_end = gps_a->lap_end(lap);

      draw_track(lap_start, lap_end, 25);
    }

  if (_hasCurrentLocation)
    {
      CGFloat px = round(_currentLocation.longitude * xa + xb);
      CGFloat py = round(_currentLocation.latitude * ya + yb);

      CGContextSetLineWidth(ctx, 3);
      CGContextSetRGBFillColor(ctx, .2, .6, 8, 1);
      CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 1);
      CGContextBeginPath(ctx);
      CGContextAddEllipseInRect(ctx, CGRectMake(px - SPOT_RADIUS,
		py - SPOT_RADIUS, SPOT_RADIUS*2, SPOT_RADIUS*2));
      CGContextDrawPath(ctx, kCGPathFillStroke);
    }

  CGContextRestoreGState(ctx);
}

@end
