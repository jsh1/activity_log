// -*- c-style: gnu -*-

#import "ActDevice.h"

@interface ActGarminDevice : ActDevice
{
  NSString *_path;
}

- (id)initWithPath:(NSString *)path;

@property(nonatomic, readonly) NSString *path;

@end
