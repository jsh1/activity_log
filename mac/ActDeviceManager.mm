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

#import "ActDeviceManager.h"

#import "ActDevice.h"
#import "ActGarminDevice.h"

NSString *const ActDeviceManagerDevicesDidChange
  = @"ActDeviceManagerDevicesDidChange";

@implementation ActDeviceManager
{
  NSMutableDictionary *_devices;	// URL -> ActDevice
}

+ (ActDeviceManager *)sharedDeviceManager
{
  static ActDeviceManager *_manager;

  if (_manager == nil)
    _manager = [[self alloc] init];

  return _manager;
}

- (id)init
{
  self = [super init];
  if (self == nil)
    return nil;

  _devices = [[NSMutableDictionary alloc] init];

  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
  [workspace.notificationCenter
   addObserver:self selector:@selector(volumeDidMount:)
   name:NSWorkspaceDidMountNotification object:nil];
  [workspace.notificationCenter
   addObserver:self selector:@selector(volumeDidUnmount:)
   name:NSWorkspaceDidUnmountNotification object:nil];

  [self rescanVolumes];

  return self;
}

- (void)dealloc
{
  [[NSWorkspace sharedWorkspace].notificationCenter removeObserver:self];


}

- (NSArray *)allDevices
{
  return _devices.allValues;
}

- (ActDevice *)deviceForURL:(NSURL *)url
{
  NSString *path = url.path;
  NSFileManager *fm = [NSFileManager defaultManager];

  for (NSString *dir in @[@"Garmin", @"GARMIN"])
    {
      NSString *gp = [path stringByAppendingPathComponent:dir];
      if ([fm fileExistsAtPath:gp])
	return [[ActGarminDevice alloc] initWithPath:gp];
    }

  return nil;
}

- (void)rescanVolumes
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  /* FIXME: it's not clear what the alternatives to these are. */

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"

  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
  NSArray *local_volumes = workspace.mountedLocalVolumePaths;
  NSArray *removable_volumes = workspace.mountedRemovableMedia;

#pragma clang diagnostic pop

  for (NSString *path in local_volumes)
    {
      NSURL *url = [NSURL fileURLWithPath:path];
      if (ActDevice *device = [self deviceForURL:url])
	dict[url] = device;
    }

  for (NSString *path in removable_volumes)
    {
      NSURL *url = [NSURL fileURLWithPath:path];
      if (ActDevice *device = [self deviceForURL:url])
	dict[url] = device;
    }

  if (![_devices isEqual:dict])
    {
      _devices = dict;

      [[NSNotificationCenter defaultCenter] postNotificationName:
       ActDeviceManagerDevicesDidChange object:self];
    }
}

- (void)volumeDidMount:(NSNotification *)note
{
  NSURL *url = note.userInfo[NSWorkspaceVolumeURLKey];

  if (_devices[url] != nil)
    return;

  if (ActDevice *device = [self deviceForURL:url])
    {
      _devices[url] = device;

      [[NSNotificationCenter defaultCenter] postNotificationName:
       ActDeviceManagerDevicesDidChange object:self];
    }
}

- (void)volumeDidUnmount:(NSNotification *)note
{
  NSURL *url = note.userInfo[NSWorkspaceVolumeURLKey];

  ActDevice *device = _devices[url];
  if (device == nil)
    return;

  [device invalidate];

  [_devices removeObjectForKey:url];

  [[NSNotificationCenter defaultCenter] postNotificationName:
   ActDeviceManagerDevicesDidChange object:self];
}

@end
