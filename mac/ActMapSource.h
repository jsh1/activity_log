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

#import <Foundation/Foundation.h>

struct ActMapTileIndex
{
  int x;
  int y;
  int z;

  ActMapTileIndex(int x, int y, int z);
};

// Abstract map-source class

@interface ActMapSource : NSObject

@property(nonatomic, assign, readonly, getter=isLoading) BOOL loading;

@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, copy, readonly) NSString *scheme;
@property(nonatomic, assign, readonly) int minZoom;
@property(nonatomic, assign, readonly) int maxZoom;
@property(nonatomic, assign, readonly) int tileWidth;
@property(nonatomic, assign, readonly) int tileHeight;
@property(nonatomic, assign, readonly) BOOL supportsRetina;

- (NSURL *)URLForTileIndex:(const ActMapTileIndex &)tile retina:(BOOL)flag;

@end

// ActMapSource notifications

extern NSString *const ActMapSourceDidFinishLoading;

// implementation details

inline
ActMapTileIndex::ActMapTileIndex(int a, int b, int c)
: x(a), y(b), z(c)
{
}
