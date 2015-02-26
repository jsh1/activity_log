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

#import "ActTileJSONMapSource.h"

@implementation ActTileJSONMapSource

+ (ActTileJSONMapSource *)mapSourceFromResource:(NSString *)name
{
  NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"json"];
  if (path == nil)
    return nil;

  NSData *data = [NSData dataWithContentsOfFile:path];
  if (data == nil)
    return nil;

  return [[[self alloc] initWithJSONData:data] autorelease];
}

+ (ActTileJSONMapSource *)mapSourceFromURL:(NSURL *)url
{
  if ([url isFileURL])
    {
      NSData *data = [NSData dataWithContentsOfURL:url];
      if (data == nil)
	return nil;

      return [[[self alloc] initWithJSONData:data] autorelease];
    }
  else
    {
      /* Load remote JSON data URLs asynchronously, avoids noticeably
	 blocking on startup. */

      ActTileJSONMapSource *src = [[self alloc] initWithJSONData:nil];
      [src startLoadingURL:url];
      return [src autorelease];
    }
}

- (id)initWithJSONData:(NSData *)data
{
  self = [super init];
  if (self == nil)
    return nil;

  if (data != nil)
    {
      _dict = [[NSJSONSerialization
		JSONObjectWithData:data options:0 error:nil] retain];

      if (_dict == nil)
	{
	  [self release];
	  return nil;
	}
    }

  return self;
}

- (void)dealloc
{
  [_dict release];

  [_url cancel];
  [_url release];

  [super dealloc];
}

- (void)startLoadingURL:(NSURL *)url
{
  assert(_url == nil);

  _url = [[ActCachedURL alloc] init];
  [_url setURL:url];
  [_url setDelegate:self];

  [[ActURLCache sharedURLCache] loadURL:_url];
}

- (BOOL)isLoading
{
  return _url != nil;
}

- (NSString *)name
{
  if (NSString *name = _dict[@"name"])
    return name;
  else if (_url != nil)
    return @"(loading)";
  else if (_dict == nil)
    return @"(null)";
  else
    return @"unknown";
}

- (NSString *)scheme
{
  if (NSString *str = _dict[@"scheme"])
    return str;
  else
    return @"xyz";
}

- (int)minZoom
{
  if (NSNumber *obj = _dict[@"minzoom"])
    return [obj intValue];
  else
    return 0;
}

- (int)maxZoom
{
  if (NSNumber *obj = _dict[@"maxzoom"])
    return [obj intValue];
  else
    return 22;
}

- (BOOL)supportsRetina
{
  return [_dict[@"autoscale"] boolValue];
}

- (NSURL *)URLForTileIndex:(const ActMapTileIndex &)tile retina:(BOOL)flag
{
  NSArray *array = _dict[@"tiles"];
  if ([array count] < 1)
    return nil;

  int ty = tile.y;
  if ([[self scheme] isEqualToString:@"xyz"])
    ty = (1 << tile.z) - ty - 1;

  NSString *str = array[0];
  str = [str stringByReplacingOccurrencesOfString:@"{x}"
         withString:[NSString stringWithFormat:@"%d", tile.x]];
  str = [str stringByReplacingOccurrencesOfString:@"{y}"
         withString:[NSString stringWithFormat:@"%d", ty]];
  str = [str stringByReplacingOccurrencesOfString:@"{z}"
         withString:[NSString stringWithFormat:@"%d", tile.z]];

  if (flag) 
    {
      str = [str stringByReplacingOccurrencesOfString:@".png"
	     withString:@"@2x.png"];
    }

  return [NSURL URLWithString:str];
}

// ActURLCacheDelegate methods

- (void)cachedURLDidFinish:(ActCachedURL *)url
{
  [_dict release];
  _dict = [[NSJSONSerialization JSONObjectWithData:[url data]
	    options:0 error:nil] retain];

  [_url release];
  _url = nil;

  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActMapSourceDidFinishLoading object:self];
}

@end
