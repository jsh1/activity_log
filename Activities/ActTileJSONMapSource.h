// -*- c-style: gnu -*-

#import "ActMapSource.h"

#import "ActURLCache.h"

@interface ActTileJSONMapSource : ActMapSource <ActURLCacheDelegate>
{
@private
  NSDictionary *_dict;
  ActCachedURL *_url;
}

+ (ActTileJSONMapSource *)mapSourceFromResource:(NSString *)name;

+ (ActTileJSONMapSource *)mapSourceFromURL:(NSURL *)url;

- (id)initWithJSONData:(NSData *)data;

@end
