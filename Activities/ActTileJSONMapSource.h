// -*- c-style: gnu -*-

#import "ActMapSource.h"

@interface ActTileJSONMapSource : ActMapSource <NSURLConnectionDataDelegate>
{
@private
  NSDictionary *_dict;
  NSURLConnection *_connection;
  NSMutableData *_connectionData;
}

+ (ActTileJSONMapSource *)mapSourceFromResource:(NSString *)name;

+ (ActTileJSONMapSource *)mapSourceFromURL:(NSURL *)url;

- (id)initWithJSONData:(NSData *)data;

@end
