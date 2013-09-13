// -*- c-style: gnu -*-

#import "ActMapSource.h"

NSString *const ActMapSourceDidFinishLoading = @"ActMapSourceDidFinishLoading";

@implementation ActMapSource

- (BOOL)isLoading
{
  return NO;
}

- (NSString *)name
{
  return @"unknown";
}

- (NSString *)scheme
{
  return @"xyz";
}

- (int)minZoom
{
  return 0;
}

- (int)maxZoom
{
  return 0;
}

- (int)tileWidth
{
  return 256;
}

- (int)tileHeight
{
  return 256;
}

- (NSURL *)URLForTileIndex:(const ActMapTileIndex &)tile
{
  return nil;
}

@end
