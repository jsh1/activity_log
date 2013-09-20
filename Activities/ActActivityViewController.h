// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

#import "act-activity.h"

@class ActWindowController;

@interface ActActivityViewController : NSViewController <NSSplitViewDelegate>
{
  ActWindowController *_controller;

  act::activity_storage_ref _activity_storage;
  std::unique_ptr<act::activity> _activity;

  NSInteger _selectedLapIndex;
}

@property(nonatomic, assign) ActWindowController *controller;

@property(nonatomic) act::activity_storage_ref activityStorage;
@property(nonatomic, readonly) act::activity *activity;

@property(nonatomic) NSInteger selectedLapIndex;

@property(nonatomic, copy) NSString *bodyString;

- (id)init;

- (NSString *)stringForField:(NSString *)name;
- (void)setString:(NSString *)str forField:(NSString *)name;
- (BOOL)isFieldReadOnly:(NSString *)name;

@property(nonatomic, copy) NSDate *dateField;

- (void)activityDidChange;
- (void)activityDidChangeField:(NSString *)name;
- (void)activityDidChangeBody;
- (void)selectedLapDidChange;

@end
