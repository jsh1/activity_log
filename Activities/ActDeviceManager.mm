// -*- c-style: gnu -*-

#import "ActDeviceManager.h"

#import "ActDevice.h"
#import "ActGarminDevice.h"

NSString *const ActDeviceManagerDevicesDidChange
  = @"ActDeviceManagerDevicesDidChange";

@implementation ActDeviceManager

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

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(volumeDidMount:)
   name:NSWorkspaceDidMountNotification object:nil];
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(volumeDidUnmount:)
   name:NSWorkspaceDidUnmountNotification object:nil];

  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [_devices release];

  [super dealloc];
}

- (NSArray *)devices
{
  return [_devices allValues];
}

- (void)volumeDidMount:(NSNotification *)note
{
  NSURL *url = [[note userInfo] objectForKey:NSWorkspaceVolumeURLKey];

  if ([_devices objectForKey:url] != nil)
    return;

  NSString *path = [url path];
  NSFileManager *fm = [NSFileManager defaultManager];

  if ([fm fileExistsAtPath:[path stringByAppendingPathComponent:@"Garmin"]])
    {
      ActDevice *device = [[ActGarminDevice alloc] initWithPath:
			   [path stringByAppendingPathComponent:@"Garmin"]];

      if (device != nil)
	{
	  [_devices setObject:device forKey:url];
	  [[NSNotificationCenter defaultCenter] postNotificationName:
	   ActDeviceManagerDevicesDidChange object:self];
	}
    }
}

- (void)volumeDidUnmount:(NSNotification *)note
{
  NSURL *url = [[note userInfo] objectForKey:NSWorkspaceVolumeURLKey];

  ActDevice *device = [_devices objectForKey:url];
  if (device == nil)
    return;

  [device invalidate];

  [_devices removeObjectForKey:url];

  [[NSNotificationCenter defaultCenter] postNotificationName:
   ActDeviceManagerDevicesDidChange object:self];
}

@end
