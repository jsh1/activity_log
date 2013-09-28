// -*- c-style: gnu -*-

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
  if (NSString *name = [_dict objectForKey:@"name"])
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
  if (NSString *str = [_dict objectForKey:@"scheme"])
    return str;
  else
    return @"xyz";
}

- (int)minZoom
{
  if (NSNumber *obj = [_dict objectForKey:@"minzoom"])
    return [obj intValue];
  else
    return 0;
}

- (int)maxZoom
{
  if (NSNumber *obj = [_dict objectForKey:@"maxzoom"])
    return [obj intValue];
  else
    return 22;
}

- (NSURL *)URLForTileIndex:(const ActMapTileIndex &)tile
{
  NSArray *array = [_dict objectForKey:@"tiles"];
  if ([array count] < 1)
    return nil;

  int ty = tile.y;
  if ([[self scheme] isEqualToString:@"xyz"])
    ty = (1 << tile.z) - ty - 1;

  NSString *str = [array objectAtIndex:0];
  str = [str stringByReplacingOccurrencesOfString:@"{x}"
         withString:[NSString stringWithFormat:@"%d", tile.x]];
  str = [str stringByReplacingOccurrencesOfString:@"{y}"
         withString:[NSString stringWithFormat:@"%d", ty]];
  str = [str stringByReplacingOccurrencesOfString:@"{z}"
         withString:[NSString stringWithFormat:@"%d", tile.z]];

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
