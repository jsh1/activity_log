// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

#import "ActURLCache.h"

#import "act-types.h"

@class ActMapSource;

@protocol ActMapViewDelegate;

@interface ActMapView : NSView <ActURLCacheDelegate>
{
  ActMapSource *_mapSource;
  int _mapZoom;
  act::location _mapCenter;

  IBOutlet id<ActMapViewDelegate> _mapDelegate;

  uint32_t _seed;
  NSMutableDictionary *_images;		/* NSURL -> ActMapImage */
}

@property(nonatomic, retain) ActMapSource *mapSource;

@property(nonatomic) int mapZoom;
@property(nonatomic) act::location mapCenter;

@property(nonatomic, assign) id<ActMapViewDelegate> mapDelegate;

- (void)displayRegion:(const act::location_region &)rgn;

- (void)invalidate;

@end

@protocol ActMapViewDelegate <NSObject>
@optional

- (void)mapView:(ActMapView *)view drawOverlayRect:(NSRect)r
    mapBottomLeft:(const act::location &)loc_ll
    topRight:(const act::location &)loc_ur;

@end
