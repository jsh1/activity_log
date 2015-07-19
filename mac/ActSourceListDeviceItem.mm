/* -*- c-style: gnu -*-

   Copyright (c) 2013 John Harper <jsh@unfactored.org>

   Permission is hereby granted, free of charge, to any person
   obtaining a copy of this software and associated documentation files
   (the "Software"), to deal in the Software without restriction,
   including without limitation the rights to use, copy, modify, merge,
   publish, distribute, sublicense, and/or sell copies of the Software,
   and to permit persons to whom the Software is furnished to do so,
   subject to the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE. */

#import "ActSourceListDeviceItem.h"

#import "ActDevice.h"
#import "ActWindowController.h"

#import <set>

@implementation ActSourceListDeviceItem

@synthesize device = _device;

+ (id)itemWithDevice:(ActDevice *)device
{
  return [[self alloc] initWithDevice:device];
}

- (id)initWithDevice:(ActDevice *)device
{
  self = [super init];
  if (self == nil)
    return nil;

  _device = device;

  self.name = _device.name;

  return self;
}


- (void)select
{
  self.controller.selectedDevice = _device;
  self.controller.windowMode = ActWindowMode_Importer;
}

- (BOOL)hasBadge
{
  return YES;
}

- (NSInteger)badgeValue
{
  std::set<std::string> activities;

  for (NSURL *url in _device.activityURLs)
    activities.insert(url.path.lastPathComponent.UTF8String);

  if (activities.size() != 0)
    {
      for (const auto &it : self.controller.database->items())
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
