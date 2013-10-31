// -*- c-style: gnu -*-

#import "ActDevice.h"

@implementation ActDevice

@synthesize delegate = _delegate;

- (NSString *)name
{
  return @"Unknown Device";
}

- (NSArray *)activityURLs
{
  return [NSArray array];
}

- (void)invalidate
{
  if ([_delegate respondsToSelector:@selector(deviceWasRemoved:)])
    [_delegate deviceWasRemoved:self];

  _delegate = nil;
}

- (void)dealloc
{
  [self invalidate];
  [super dealloc];
}

@end
