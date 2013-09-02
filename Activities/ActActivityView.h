// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

#import "act-activity.h"

@class ActWindowController;

@interface ActActivityView : NSView
{
  IBOutlet ActWindowController *_controller;

  act::activity_storage_ref _activity_storage;
  std::unique_ptr<act::activity> _activity;

  NSInteger _selectedLapIndex;
}

@property(nonatomic) act::activity_storage_ref activityStorage;
@property(nonatomic, readonly) act::activity *activity;

@property(nonatomic) NSInteger selectedLapIndex;

- (void)activityDidChange;
- (void)activityDidChangeField:(NSString *)name;
- (void)activityDidChangeBody;
- (void)selectedLapDidChange;

- (void)updateHeight;

- (CGFloat)preferredHeightForWidth:(CGFloat)width;

- (void)layoutSubviews;

- (NSFont *)font;

@end
