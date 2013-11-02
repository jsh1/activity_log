// -*- c-style: gnu -*-

#import "ActSourceListDeviceItem.h"

#import "ActDevice.h"
#import "ActWindowController.h"

@implementation ActSourceListDeviceItem

@synthesize device = _device;

+ (id)itemWithDevice:(ActDevice *)device
{
  return [[[self alloc] initWithDevice:device] autorelease];
}

- (id)initWithDevice:(ActDevice *)device
{
  self = [super init];
  if (self == nil)
    return nil;

  _device = [device retain];

  [self setName:[_device name]];

  return self;
}

- (void)dealloc
{
  [_device release];
  [super dealloc];
}

- (void)select
{
  [_controller setSelectedDevice:_device];
  [_controller setWindowMode:ActWindowMode_Importer];
}

@end
