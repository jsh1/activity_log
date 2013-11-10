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

- (NSPoint)pointAtLocation:(const act::location &)loc;

@end

@protocol ActMapViewDelegate <NSObject>
@optional

- (void)mapView:(ActMapView *)view drawOverlayRect:(NSRect)r
    mapBottomLeft:(const act::location &)loc_ll
    topRight:(const act::location &)loc_ur;

@end
