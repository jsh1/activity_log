// -*- c-style: gnu -*-

#import "ActMapView.h"

#import "ActMapSource.h"

#import <algorithm>

#define DEBUG_URLS 0

#define DRAG_THRESH 3
#define DRAG_MASK (NSLeftMouseDraggedMask | NSLeftMouseUpMask)

@interface ActMapImage : NSObject
{
@public
  uint32_t _seed;
  CGImageRef _image;
  NSMutableData *_data;
  NSURLConnection *_connection;
  BOOL _failed;
}

- (void)drawInRect:(CGRect)r;

- (void)invalidate;

@end


@implementation ActMapView

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self == nil)
    return nil;

  _mapCenter.longitude = -1.98333;
  _mapCenter.latitude = -50.71666;
  _mapZoom = 12;

  _images = [[NSMutableDictionary alloc] init];

  return self;
}

- (void)invalidate
{
  for (NSURL *url in _images)
    {
      ActMapImage *im = [_images objectForKey:url];
      [im invalidate];
    }

  [_images release];
  _images = nil;
}

- (void)dealloc
{
  [self invalidate];
  [_mapSource release];

  [super dealloc];
}

- (ActMapSource *)mapSource
{
  return _mapSource;
}

- (void)setMapSource:(ActMapSource *)src
{
  if (_mapSource != src)
    {
      [_mapSource release];
      _mapSource = [src retain];
      [self setNeedsDisplay:YES];
    }
}

- (int)mapZoom
{
  return _mapZoom;
}

- (void)setMapZoom:(int)z
{
  if (_mapZoom != z)
    {
      _mapZoom = z;
      [self setNeedsDisplay:YES];
    }
}

- (CLLocationCoordinate2D)mapCenter
{
  return _mapCenter;
}

- (void)setMapCenter:(CLLocationCoordinate2D)l
{
  if (_mapCenter.latitude != l.latitude || _mapCenter.longitude != l.longitude)
    {
      _mapCenter = l;
      [self setNeedsDisplay:YES];
    }
}

static CGPoint
convertLocationToPoint(CLLocationCoordinate2D l)
{
  CGPoint p;
  p.x = (l.longitude + 180) / 360;
  double lat_rad = l.latitude * (M_PI / 180);
  p.y = (1 - (log(tan(lat_rad) + 1/cos(lat_rad)) / M_PI)) / 2;
  return p;
}

static CLLocationCoordinate2D
convertPointToLocation(CGPoint p)
{
  CLLocationCoordinate2D l;
  l.longitude = p.x * 360 - 180;
  l.latitude = atan(sinh(M_PI * (1 - 2 * p.y))) * 180 / M_PI;
  return l;
}

- (void)drawRect:(NSRect)r
{
  ActMapSource *src = [self mapSource];
  if (src == nil)
    return;

  _seed++;

  int zoom_min = [src minZoom];
  int zoom_max = [src maxZoom];

  int zoom = [self mapZoom];
  zoom = std::min(zoom, zoom_max);
  zoom = std::max(zoom, zoom_min);

  int n_tiles = 1 << zoom;

  double tw = [src tileWidth];
  double th = [src tileHeight];
  NSRect bounds = [self bounds];

  CGPoint origin = convertLocationToPoint([self mapCenter]);
  origin.x *= n_tiles * tw;
  origin.y *= n_tiles * th;
  origin.x -= bounds.size.width * (CGFloat).5;
  origin.y -= bounds.size.height * (CGFloat).5;
  origin.x = round(origin.x);
  origin.y = round(origin.y);
  origin.x /= tw;
  origin.y /= th;

  int tx0 = floor(origin.x);
  int ty0 = floor(origin.y);
  int tx1 = ceil(origin.x + bounds.size.width / tw);
  int ty1 = ceil(origin.y + bounds.size.height / th);

  for (int ty = ty0; ty < ty1; ty++)
    {
      if (ty < 0 || ty >= n_tiles)
	continue;

      CGFloat py = bounds.origin.y + (ty - origin.y) * th;

      for (int tx = tx0; tx < tx1; tx++)
	{
	  CGFloat px = bounds.origin.x + (tx - origin.x) * tw;

	  ActMapTileIndex tile(tx & (n_tiles - 1), ty, zoom);
	  NSURL *url = [src URLForTileIndex:tile];
	  if (url == nil)
	    continue;

	  if (ActMapImage *im = [self imageForURL:url])
	    [im drawInRect:CGRectMake(px, py, tw, th)];
	}
    }

  // cancel connections no longer needed and release unused images.

  NSMutableArray *removed = nil;

  for (NSURL *url in _images)
    {
      ActMapImage *im = [_images objectForKey:url];

      if (im->_seed != _seed)
	{
	  [im invalidate];
	  if (removed == nil)
	    removed = [[NSMutableArray alloc] init];
	  [removed addObject:url];
	}
    }
  for (NSURL *url in removed)
    [_images removeObjectForKey:url];

  [removed release];
}

- (ActMapImage *)imageForURL:(NSURL *)url
{
  ActMapImage *im = [_images objectForKey:url];

  if (im == nil)
    {
#if DEBUG_URLS
      NSLog(@"image request %@", url);
#endif

      im = [[ActMapImage alloc] init];

      [_images setObject:im forKey:url];
      [im release];
    }

  if (im->_image == NULL && im->_connection == nil && !im->_failed)
    {
      if (im->_data == nil)
	im->_data = [[NSMutableData alloc] init];

      NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
      im->_connection = [[NSURLConnection alloc] initWithRequest:request
			 delegate:self startImmediately:NO];
      [im->_connection scheduleInRunLoop:[NSRunLoop mainRunLoop]
       forMode:NSRunLoopCommonModes];
      [im->_connection start];
      [request release];
    }

  im->_seed = _seed;
  return im;
}

// NSURLConnectionDataDelegate methods

- (void)connection:(NSURLConnection *)conn
    didReceiveResponse:(NSURLResponse *)response
{
  NSURL *url = [[conn originalRequest] URL];
  ActMapImage *im = [_images objectForKey:url];

  [im->_data setLength:0];
}

- (void)connection:(NSURLConnection *)conn didFailWithError:(NSError *)error
{
  NSURL *url = [[conn originalRequest] URL];
  ActMapImage *im = [_images objectForKey:url];

  im->_failed = YES;
  [im invalidate];
}

- (void)connection:(NSURLConnection *)conn didReceiveData:(NSData *)data
{
  NSURL *url = [[conn originalRequest] URL];
  ActMapImage *im = [_images objectForKey:url];

  [im->_data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)conn
{
  NSURL *url = [[conn originalRequest] URL];
  ActMapImage *im = [_images objectForKey:url];

  if (CGImageSourceRef src
      = CGImageSourceCreateWithData((CFDataRef)im->_data, NULL))
    {
      if (CGImageRef image = CGImageSourceCreateImageAtIndex(src, 0, NULL))
	{
	  im->_image = image;
	  [self setNeedsDisplay:YES];			// FIXME: shoddy
	}

      CFRelease(src);
    }

  [im->_connection release];
  im->_connection = nil;

  [im->_data release];
  im->_data = nil;

  im->_failed = NO;
}

// Event handling

- (void)mouseDown:(NSEvent *)e
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  BOOL dragging = NO;

  NSPoint p0 = [self convertPoint:[e locationInWindow] fromView:nil];
  CGPoint c0 = convertLocationToPoint([self mapCenter]);

  CGFloat mx = (1 << _mapZoom) * [_mapSource tileWidth];
  CGFloat my = (1 << _mapZoom) * [_mapSource tileHeight];

  c0.x *= mx;
  c0.y *= my;

  while (1)
    {
      e = [[self window] nextEventMatchingMask:DRAG_MASK];

      if ([e type] != NSLeftMouseDragged)
	break;

      NSPoint p1 = [self convertPoint:[e locationInWindow] fromView:nil];

      if (!dragging && (fabs(p1.x - p0.x) >= DRAG_THRESH
			|| fabs(p1.y - p0.y) >= DRAG_THRESH))
	{
	  dragging = YES;
	}

      if (dragging)
	{
	  CGPoint c1;
	  c1.x = (c0.x + (p0.x - p1.x)) / mx;
	  c1.y = (c0.y + (p0.y - p1.y)) / my;

	  [self setMapCenter:convertPointToLocation(c1)];

	  [self displayIfNeeded];
	}

      [pool drain];
      pool = [[NSAutoreleasePool alloc] init];
    }

  [pool drain];
}

@end

@implementation ActMapImage

- (void)invalidate
{
  CGImageRelease(_image);
  _image = NULL;

  [_data release];
  _data = nil;

  [_connection cancel];
  [_connection release];
  _connection = nil;
}

- (void)dealloc
{
  [self invalidate];

  [super dealloc];
}

- (void)drawInRect:(CGRect)r
{
  if (_image != NULL)
    {
      CGContextRef ctx
	= (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
  
      CGContextDrawImage(ctx, r, _image);
    }
}

@end
