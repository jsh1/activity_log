// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>
#import <CoreLocation/CoreLocation.h>

@class ActMapSource;

@interface ActMapView : NSView <NSURLConnectionDataDelegate>
{
  ActMapSource *_mapSource;
  int _mapZoom;
  CLLocationCoordinate2D _mapCenter;

  NSMutableDictionary *_loadedImages;	/* NSURL -> CGImageRef */
  NSMutableDictionary *_activeImages;	/* NSURL -> ActMapURLConnection */
}

@property(nonatomic, retain) ActMapSource *mapSource;

@property(nonatomic) int mapZoom;
@property(nonatomic) CLLocationCoordinate2D mapCenter;

- (void)invalidate;

@end
