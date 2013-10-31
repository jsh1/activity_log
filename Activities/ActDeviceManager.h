// -*- c-style: gnu -*-

#import <Foundation/Foundation.h>

@interface ActDeviceManager : NSObject
{
  NSMutableDictionary *_devices;	// URL -> ActDevice
}

+ (ActDeviceManager *)sharedDeviceManager;

- (NSArray *)devices;

@end

// notifications

extern NSString *const ActDeviceManagerDevicesDidChange;
