// -*- c-style: gnu -*-

#import <Foundation/Foundation.h>

@class ActDevice;

@protocol ActDeviceDelegate

- (void)deviceWasRemoved:(ActDevice *)device;

@end

@interface ActDevice : NSObject
{
  id _delegate;
}

@property(nonatomic, readonly) NSString *name;

@property(nonatomic, assign) id delegate;

@property(nonatomic, readonly) NSArray *activityURLs;

- (void)invalidate;

@end
