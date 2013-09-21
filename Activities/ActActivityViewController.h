// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

#import "act-activity.h"

@class ActWindowController, ActActivitySplitView;
@class ActActivitySummaryView, ActActivityLapView;
@class ActActivityMapView, ActActivityChartView;

@interface ActActivityViewController : NSViewController <NSSplitViewDelegate>
{
  IBOutlet ActActivitySplitView *_mainSplitView;
  IBOutlet ActActivitySplitView *_middleSplitView;

  IBOutlet NSSegmentedControl *_showHideControl;
  IBOutlet NSSegmentedControl *_middleShowHideControl;

  IBOutlet ActActivitySummaryView *_summaryView;
  IBOutlet ActActivityLapView *_lapView;
  IBOutlet ActActivityMapView *_mapView;
  IBOutlet ActActivityChartView *_chartView;

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
- (BOOL)isFieldReadOnly:(NSString *)name;
- (void)setString:(NSString *)str forField:(NSString *)name;
- (void)renameField:(NSString *)oldName to:(NSString *)newName;

@property(nonatomic, copy) NSDate *dateField;

- (void)activityDidChange;
- (void)activityDidChangeField:(NSString *)name;
- (void)activityDidChangeBody;
- (void)selectedLapDidChange;

- (IBAction)controlAction:(id)sender;

- (void)updateShowHideButtons;

@end
