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

#import "ActActivityMapViewController.h"

#import "ActActivityViewController.h"

#import "act-format.h"

#define MAP_INSET 10

@interface ActActivityMapViewController ()
@property(nonatomic, readonly) ActActivityViewController *controller;
@end

CA_HIDDEN @interface AAMVPointAnnotation : MKPointAnnotation
@property(nonatomic) MKPinAnnotationColor pinColor;
@end

CA_HIDDEN @interface AAMVPolylineView : MKPolylineView
@end

CA_HIDDEN @interface AAMVLayoutGuide : NSObject <UILayoutSupport>
- (instancetype)initWithLayoutGuide:(id<UILayoutSupport>)guide;
@property(nonatomic) CGFloat length;
@end

@implementation ActActivityMapViewController
{
  UIEdgeInsets _contentInset;

  UISegmentedControl *_mapTypeControl;
  UIBarButtonItem *_mapTypeItem;

  UILongPressGestureRecognizer *_pressRecognizer;
}

- (id)init
{
  return [super initWithNibName:@"ActivityMapView" bundle:nil];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (ActActivityViewController *)controller
{
  return (ActActivityViewController *)self.parentViewController;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  _mapTypeControl = [[UISegmentedControl alloc]
		     initWithItems:@[@"Standard", @"Hybrid"]];
  [_mapTypeControl addTarget:self action:@selector(mapTypeAction:)
   forControlEvents:UIControlEventValueChanged];

  _mapTypeItem = [[UIBarButtonItem alloc] initWithCustomView:_mapTypeControl];

  MKMapView *map_view = (id)self.view;

  map_view.mapType = (MKMapType) [[NSUserDefaults standardUserDefaults]
				  integerForKey:@"ActActivityMapView.mapType"];

  NSInteger idx = -1;
  if (map_view.mapType == MKMapTypeStandard)
    idx = 0;
  else if (map_view.mapType == MKMapTypeHybrid)
    idx = 1;

  if (idx >= 0)
    _mapTypeControl.selectedSegmentIndex = idx;

  _pressRecognizer = [[UILongPressGestureRecognizer alloc]
		      initWithTarget:self action:@selector(pressAction:)];
  _pressRecognizer.minimumPressDuration = .25;
  [self.view addGestureRecognizer:_pressRecognizer];
}

- (void)setContentInset:(UIEdgeInsets)inset
{
  _contentInset = inset;
}

- (NSArray *)rightBarButtonItems
{
  return @[_mapTypeItem];
}

- (void)reloadData
{
  MKMapView *map_view = (id)self.view;

  [map_view removeAnnotations:map_view.annotations];
  [map_view removeOverlays:map_view.overlays];

  const act::activity *activity = self.controller.activity;
  if (activity == nullptr)
    return;

  const act::gps::activity *gps_data = activity->gps_data();
  if (gps_data == nullptr)
    return;

  /* Recenter map over our region of interest. */

  {
    const act::location_region &rgn = gps_data->region();

    CLLocationCoordinate2D l0, l1;
    l0.latitude = rgn.center.latitude - rgn.size.latitude*.5;
    l0.longitude = rgn.center.longitude - rgn.size.longitude*.5;
    l1.latitude = rgn.center.latitude + rgn.size.latitude*.5;
    l1.longitude = rgn.center.longitude + rgn.size.longitude*.5;

    MKMapPoint p0 = MKMapPointForCoordinate(l0);
    MKMapPoint p1 = MKMapPointForCoordinate(l1);

    double llx = std::min(p0.x, p1.x);
    double lly = std::min(p0.y, p1.y);
    double urx = std::max(p0.x, p1.x);
    double ury = std::max(p0.y, p1.y);

    MKMapRect r = MKMapRectMake(llx, lly, urx - llx, ury - lly);

    UIEdgeInsets inset = _contentInset;
    inset.top += MAP_INSET;
    inset.bottom += MAP_INSET;
    inset.left += MAP_INSET;
    inset.right += MAP_INSET;

    [map_view setVisibleMapRect:r edgePadding:inset animated:NO];
  }

  /* Add track adornments. */

  {
    std::vector<CLLocationCoordinate2D> coords;

    for (const auto &p : gps_data->points())
      {
	if (p.location.latitude != 0 && p.location.longitude != 0)
	  {
	    CLLocationCoordinate2D loc
	      = {p.location.latitude, p.location.longitude};
	    coords.push_back(loc);
	  }
      }

    for (size_t i = 0; i < gps_data->laps().size() - 1; i++)
      {
	const auto &lap = gps_data->laps()[i];
	const auto &p = gps_data->lap_end(lap);

	AAMVPointAnnotation *anno = [[AAMVPointAnnotation alloc] init];
	CLLocationCoordinate2D loc
	  = {p->location.latitude, p->location.longitude};
        anno.coordinate = loc;
	anno.title = [NSString stringWithFormat:@"Lap %d", (int)i + 1];
	std::string sub;
	act::format_distance(sub, p->distance, act::unit_type::unknown);
	anno.subtitle = [NSString stringWithUTF8String:sub.c_str()];
	anno.pinColor = MKPinAnnotationColorPurple;
	[map_view addAnnotation:anno];
      }

    if (coords.size() != 0)
      {
	AAMVPointAnnotation *first = [[AAMVPointAnnotation alloc] init];
	first.coordinate = coords.front();
	first.title = @"Start";
	first.pinColor = MKPinAnnotationColorGreen;
	[map_view addAnnotation:first];

	AAMVPointAnnotation *last = [[AAMVPointAnnotation alloc] init];
	last.coordinate = coords.back();
	last.title = @"End";
	std::string sub;
	act::format_distance(sub, gps_data->points().back().distance,
			     act::unit_type::unknown);
	last.subtitle = [NSString stringWithUTF8String:sub.c_str()];
	last.pinColor = MKPinAnnotationColorRed;
	[map_view addAnnotation:last];

	[map_view addOverlay:
	 [MKPolyline polylineWithCoordinates:&coords[0] count:coords.size()]];
      }
  }
}

- (void)mapTypeAction:(id)sender
{
  MKMapView *map_view = (id)self.view;

  map_view.mapType = (_mapTypeControl.selectedSegmentIndex == 0
		      ? MKMapTypeStandard : MKMapTypeHybrid);

  [[NSUserDefaults standardUserDefaults]
   setInteger:map_view.mapType forKey:@"ActActivityMapView.mapType"];
}

- (void)pressAction:(id)sender
{
  if (_pressRecognizer.state == UIGestureRecognizerStateBegan)
    {
      self.controller.fullscreen = !self.controller.fullscreen;

      /* Make the compass relayout if it's visible. */

      [self.view setNeedsLayout];
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView
    viewForAnnotation:(id <MKAnnotation>)annotation
{
  if ([annotation isKindOfClass:[AAMVPointAnnotation class]])
    {
      AAMVPointAnnotation *anno = (AAMVPointAnnotation *)annotation;

      MKPinAnnotationView *view
        = (id) [mapView dequeueReusableAnnotationViewWithIdentifier:
		@"pinAnnotationIdentifier"];

      if (view == nil)
	{
	  view = [[MKPinAnnotationView alloc] initWithAnnotation:anno
		  reuseIdentifier:@"pinAnnotationIdentifier"];
	  view.animatesDrop = NO;
	  view.canShowCallout = YES;
	}

      view.rightCalloutAccessoryView = nil;
      view.pinColor = anno.pinColor;
      return view;
    }

  return nil;
}

- (MKOverlayView *)mapView:(MKMapView *)mapView
    viewForOverlay:(id <MKOverlay>)overlay
{
  if ([overlay isKindOfClass:[MKPolyline class]])
    {
      AAMVPolylineView *view = [[AAMVPolylineView alloc]
				initWithPolyline:(MKPolyline *)overlay];
      view.strokeColor = [UIColor colorWithRed:1 green:.1 blue:0 alpha:.65];
      view.lineJoin = kCGLineJoinBevel;
      return view;
    }

  return nil;
}

/* For the map view compass layout. */

- (id<UILayoutSupport>)topLayoutGuide
{
  AAMVLayoutGuide *guide = [[AAMVLayoutGuide alloc]
    initWithLayoutGuide:super.topLayoutGuide];
  guide.length = self.controller.fullscreen ? 0 : _contentInset.top;
  return guide;
}

@end

@implementation AAMVPointAnnotation
@synthesize pinColor = _pinColor;
@end

@implementation AAMVPolylineView

- (void)applyStrokePropertiesToContext:(CGContextRef)ctx
    atZoomScale:(MKZoomScale)s
{
  [super applyStrokePropertiesToContext:ctx atZoomScale:s];
  CGContextSetLineWidth(ctx, 3 / s);
}

@end

@implementation AAMVLayoutGuide
{
  id<UILayoutSupport> _guide;
}

@synthesize length = _length;

- (instancetype)initWithLayoutGuide:(id<UILayoutSupport>)guide
{
  self = [super init];
  if (self != nil)
    _guide = guide;
  return self;
}

- (NSLayoutYAxisAnchor *)topAnchor
{
  return _guide.topAnchor;
}

- (NSLayoutYAxisAnchor *)bottomAnchor
{
  return _guide.bottomAnchor;
}

- (NSLayoutDimension *)heightAnchor
{
  return _guide.heightAnchor;
}

@end
