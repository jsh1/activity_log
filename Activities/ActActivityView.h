// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

#import "act-activity.h"

@class ActWindowController;

@interface ActActivityView : NSView
{
@private
  IBOutlet ActWindowController *_controller;

  act::activity_storage_ref _activity_storage;
  std::unique_ptr<act::activity> _activity;
}

@property act::activity_storage_ref activityStorage;

@end
