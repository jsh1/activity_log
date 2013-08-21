// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

#import "act-activity.h"

@class ActWindowController;

@interface ActActivityView : NSView
{
  IBOutlet ActWindowController *_controller;

  act::activity_storage_ref _activity_storage;
  std::unique_ptr<act::activity> _activity;
}

@property(nonatomic) act::activity_storage_ref activityStorage;
@property(nonatomic, readonly) act::activity *activity;

- (void)activityDidChange;

- (CGFloat)preferredHeightForWidth:(CGFloat)width;

- (void)layoutSubviews;

@end
