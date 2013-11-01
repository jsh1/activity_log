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

  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
  [[workspace notificationCenter]
   addObserver:self selector:@selector(volumeDidMount:)
   name:NSWorkspaceDidMountNotification object:nil];
  [[workspace notificationCenter]
   addObserver:self selector:@selector(volumeDidUnmount:)
   name:NSWorkspaceDidUnmountNotification object:nil];

  [self rescanVolumes];

  return self;
}

- (void)dealloc
{
  [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];

  [_devices release];

  [super dealloc];
}

- (NSArray *)devices
{
  return [_devices allValues];
}

- (ActDevice *)deviceForURL:(NSURL *)url
{
  NSString *path = [url path];
  NSFileManager *fm = [NSFileManager defaultManager];

  if ([fm fileExistsAtPath:[path stringByAppendingPathComponent:@"Garmin"]])
    {
      return [[[ActGarminDevice alloc] initWithPath:
	       [path stringByAppendingPathComponent:@"Garmin"]] autorelease];
    }
  else
    return nil;
}

- (void)rescanVolumes
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];

  for (NSString *path in [workspace mountedLocalVolumePaths])
    {
      NSURL *url = [NSURL fileURLWithPath:path];
      if (ActDevice *device = [self deviceForURL:url])
	[dict setObject:device forKey:url];
    }

  for (NSString *path in [workspace mountedRemovableMedia])
    {
      NSURL *url = [NSURL fileURLWithPath:path];
      if (ActDevice *device = [self deviceForURL:url])
	[dict setObject:device forKey:url];
    }

  if (![_devices isEqual:dict])
    {
      [_devices release];
      _devices = [dict retain];

      [[NSNotificationCenter defaultCenter] postNotificationName:
       ActDeviceManagerDevicesDidChange object:self];
    }
}

- (void)volumeDidMount:(NSNotification *)note
{
  NSURL *url = [[note userInfo] objectForKey:NSWorkspaceVolumeURLKey];

  if ([_devices objectForKey:url] != nil)
    return;

  if (ActDevice *device = [self deviceForURL:url])
    {
      [_devices setObject:device forKey:url];

      [[NSNotificationCenter defaultCenter] postNotificationName:
       ActDeviceManagerDevicesDidChange object:self];
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
