// -*- c-style: gnu -*-

#import "ActMapSource.h"

@interface ActTileJSONMapSource : ActMapSource
{
  NSDictionary *_dict;
}

+ (ActTileJSONMapSource *)mapSourceFromResource:(NSString *)name;

+ (ActTileJSONMapSource *)mapSourceFromURL:(NSURL *)url;

- (id)initWithJSONData:(NSData *)data;

@end
