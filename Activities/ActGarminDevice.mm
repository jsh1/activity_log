// -*- c-style: gnu -*-

#import "ActGarminDevice.h"

// FIXME: really we should look for and parse the GarminDevice.xml file
// in the root of the device's filesystem. But that's a lot of work
// that's not really needed right now.

#define ACTIVITTY_PATH "Garmin/Activities"

@implementation ActGarminDevice

@synthesize path = _path;

- (id)initWithPath:(NSString *)path
{
  self = [super init];
  if (self == nil)
    return nil;

  _path = [path copy];

  return self;
}

- (void)dealloc
{
  [_path release];

  [super dealloc];
}

- (NSString *)name
{
  return @"Garmin Device";
}

- (NSArray *)activityURLs
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *path = [_path stringByAppendingPathComponent:@ACTIVITTY_PATH];

  if (![fm fileExistsAtPath:path])
    return [NSArray array];

  NSMutableArray *array = [NSMutableArray array];

  for (NSString *file in [fm contentsOfDirectoryAtPath:path error:nullptr])
    {
      if ([[file pathExtension] isEqualToString:@"fit"])
	[array addObject:[NSURL fileURLWithPath:[path stringByAppendingPathComponent:file]]];
    }

  return array;
}

@end
