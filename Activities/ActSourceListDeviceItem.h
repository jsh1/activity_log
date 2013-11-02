// -*- c-style: gnu -*-

#import "ActSourceListItem.h"

@class ActDevice;

@interface ActSourceListDeviceItem : ActSourceListItem
{
  ActDevice *_device;
}

+ (id)itemWithDevice:(ActDevice *)device;

- (id)initWithDevice:(ActDevice *)device;

@property(nonatomic, readonly) ActDevice *device;

@end
