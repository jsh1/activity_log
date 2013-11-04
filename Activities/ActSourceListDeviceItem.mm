// -*- c-style: gnu -*-

#import "ActSourceListDeviceItem.h"

#import "ActDevice.h"
#import "ActWindowController.h"

#import <set>

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

- (BOOL)hasBadge
{
  return YES;
}

- (NSInteger)badgeValue
{
  std::set<std::string> activities;

  for (NSURL *url in [_device activityURLs])
    activities.insert([[[url path] lastPathComponent] UTF8String]);

  if (activities.size() != 0)
    {
      for (const auto &it : [_controller database]->items())
	{
	  if (const std::string *s = it.storage()->field_ptr("GPS-File"))
	    {
	      auto pos = activities.find(*s);

	      if (pos != activities.end())
		{
		  activities.erase(pos);

		  if (activities.size() == 0)
		    break;
		}
	    }
	}
    }

  return activities.size();
}

@end
