// -*- c-style: gnu -*-

#import "ActMapView.h"

#import "ActMapSource.h"

#import <algorithm>

#define DEBUG_URLS 0

@interface ActMapURLConnection : NSURLConnection
{
  NSMutableData *_data;
}
- (void)resetData;
- (void)appendData:(NSData *)data;
- (CGImageRef)copyCGImage;
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

  _loadedImages = [[NSMutableDictionary alloc] init];
  _activeImages = [[NSMutableDictionary alloc] init];

  return self;
}

- (void)invalidate
{
  for (NSURL *url in _activeImages)
    {
      ActMapURLConnection *conn = [_activeImages objectForKey:url];
      [conn cancel];
    }

  [_activeImages release];
  _activeImages = nil;

  [_loadedImages release];
  _loadedImages = nil;
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

#if UNUSED_CODE
static CLLocationCoordinate2D
convertPointToLocation(CGPoint p)
{
  CLLocationCoordinate2D l;
  l.longitude = p.x * 360 - 180;
  l.latitude = atan(sinh(M_PI * (1 - 2 * p.y))) * 180 / M_PI;
  return l;
}
#endif

- (void)drawRect:(NSRect)r
{
  ActMapSource *src = [self mapSource];
  if (src == nil)
    return;

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

  CGContextRef ctx
    = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];

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

	  if (CGImageRef im = [self copyImageForURL:url])
	    {
	      CGContextDrawImage(ctx, CGRectMake(px, py, tw, th), im);
	      CGImageRelease(im);
	    }
	}
    }
}

- (CGImageRef)copyImageForURL:(NSURL *)url
{
  if (id obj = [_loadedImages objectForKey:url])
    {
      if (CFGetTypeID(obj) == CGImageGetTypeID())
	return CGImageRetain((CGImageRef)obj);
      else
	return NULL;
    }

#if DEBUG_URLS
  NSLog(@"image request %@", url);
#endif

  ActMapURLConnection *conn = [_activeImages objectForKey:url];

  if (conn == nil)
    {
      NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];

      conn = [[ActMapURLConnection alloc]
	      initWithRequest:request delegate:self startImmediately:YES];

      if (conn != nil)
	{
	  [_activeImages setObject:conn forKey:url];
	  [conn release];
	}
    }

  [_loadedImages setObject:[NSNull null] forKey:url];

  return NULL;
}

// NSURLConnectionDataDelegate methods

- (void)connection:(NSURLConnection *)conn
    didReceiveResponse:(NSURLResponse *)response
{
  [(ActMapURLConnection *)conn resetData];
}

- (void)connection:(NSURLConnection *)conn didFailWithError:(NSError *)error
{
  NSURL *url = [[conn originalRequest] URL];

  [_activeImages removeObjectForKey:url];
}

- (void)connection:(NSURLConnection *)conn didReceiveData:(NSData *)data
{
  [(ActMapURLConnection *)conn appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)conn
{
  NSURL *url = [[conn originalRequest] URL];

  [_activeImages removeObjectForKey:url];

  if (CGImageRef im = [(ActMapURLConnection *)conn copyCGImage])
    {
      [_loadedImages setObject:(id)im forKey:url];
      CGImageRelease(im);
      [self setNeedsDisplay:YES];		// FIXME: shoddy
    }
}

@end

@implementation ActMapURLConnection

- (id)initWithRequest:(NSURLRequest *)req delegate:(id)obj
    startImmediately:(BOOL)flag
{
  self = [super initWithRequest:req delegate:obj startImmediately:flag];
  if (self == nil)
    return nil;

  _data = [[NSMutableData alloc] init];

  return self;
}

- (void)dealloc
{
  [_data release];

  [super dealloc];
}

- (void)resetData
{
  [_data setLength:0];
}

- (void)appendData:(NSData *)data
{
  [_data appendData:data];
}

- (CGImageRef)copyCGImage
{
  if (CGImageSourceRef src
      = CGImageSourceCreateWithData((CFDataRef)_data, NULL))
    {
      CGImageRef im = CGImageSourceCreateImageAtIndex(src, 0, NULL);
      CFRelease(src);
      return im;
    }
  else
    return NULL;
}

@end
