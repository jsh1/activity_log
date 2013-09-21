// -*- c-style: gnu -*-

#import "ActActivityViewController.h"

#import "ActActivityChartView.h"
#import "ActActivityLapView.h"
#import "ActActivityMapView.h"
#import "ActActivitySummaryView.h"
#import "ActActivitySubview.h"
#import "ActActivitySplitView.h"
#import "ActWindowController.h"

#import "act-format.h"

@implementation ActActivityViewController

@synthesize controller = _controller;

- (id)init
{
  self = [super initWithNibName:@"ActActivityView"
	  bundle:[NSBundle mainBundle]];
  if (self == nil)
    return nil;

  _selectedLapIndex = -1;

  return self;
}

- (void)viewDidLoad
{
  [self updateShowHideButtons];
}

- (act::activity_storage_ref)activityStorage
{
  return _activity_storage;
}

- (void)setActivityStorage:(act::activity_storage_ref)storage
{
  if (_activity_storage != storage)
    {
      _activity_storage = storage;
      _activity.reset();

      [self activityDidChange];
    }
}

- (act::activity *)activity
{
  if (!_activity && _activity_storage)
    _activity.reset(new act::activity(_activity_storage));

  return _activity.get();
}

- (NSInteger)selectedLapIndex
{
  return _selectedLapIndex;
}

- (void)setSelectedLapIndex:(NSInteger)idx
{
  if (_selectedLapIndex != idx)
    {
      _selectedLapIndex = idx;

      [self selectedLapDidChange];
    }
}

- (void)activityDidChange
{
  [[self view] activityDidChange];
}

- (void)activityDidChangeField:(NSString *)name
{
  [[self view] activityDidChangeField:name];
}

- (void)activityDidChangeBody
{
  [[self view] activityDidChangeBody];
}

- (void)selectedLapDidChange
{
  [[self view] selectedLapDidChange];
}

- (NSString *)bodyString
{
  if (const act::activity *a = [self activity])
    return [_controller bodyStringOfActivity:*a];
  else
    return @"";
}

- (void)setBodyString:(NSString *)str
{
  if (act::activity *a = [self activity])
    [_controller setBodyString:str ofActivity:*a];
}

- (NSString *)stringForField:(NSString *)name
{
  if (const act::activity *a = [self activity])
    return [_controller stringForField:name ofActivity:*a];
  else
    return nil;
}

- (BOOL)isFieldReadOnly:(NSString *)name
{
  const char *field_name = [name UTF8String];

  if (const act::activity *a = [self activity])
    return [_controller isFieldReadOnly:name ofActivity:*a];
  else
    return field_read_only_p(act::lookup_field_id(field_name));
}

- (void)setString:(NSString *)str forField:(NSString *)name
{
  if (act::activity *a = [self activity])
    [_controller setString:str forField:name ofActivity:*a];
}

- (void)renameField:(NSString *)oldName to:(NSString *)newName
{
  if (act::activity *a = [self activity])
    [_controller renameField:oldName to:(NSString *)newName ofActivity:*a];
}

- (NSDate *)dateField
{
  if (const act::activity *a = [self activity])
    return [NSDate dateWithTimeIntervalSince1970:a->date()];
  else
    return nil;
}

- (void)setDateField:(NSDate *)date
{
  NSString *value = nil;

  if (date != nil)
    {
      std::string str;
      act::format_date_time(str, (time_t) [date timeIntervalSince1970]);
      value = [NSString stringWithUTF8String:str.c_str()];
    }

  [self setString:value forField:@"Date"];
}

- (IBAction)controlAction:(id)sender
{
  if (sender == _showHideControl)
    {
      [_mainSplitView setSubview:_summaryView
       collapsed:![_showHideControl isSelectedForSegment:0]];
      [_mainSplitView setSubview:_middleSplitView
       collapsed:![_showHideControl isSelectedForSegment:1]];
      [_mainSplitView setSubview:_chartView
       collapsed:![_showHideControl isSelectedForSegment:2]];

      [self updateShowHideButtons];
    }
  else if (sender == _middleShowHideControl)
    {
      [_middleSplitView setSubview:_lapView
       collapsed:![_middleShowHideControl isSelectedForSegment:0]];

      [self updateShowHideButtons];
    }
}

- (void)updateShowHideButtons
{
  [_showHideControl setSelected:
   ![_mainSplitView isSubviewCollapsed:_summaryView] forSegment:0];
  [_showHideControl setSelected:
   ![_mainSplitView isSubviewCollapsed:_middleSplitView] forSegment:1];
  [_showHideControl setSelected:
   ![_mainSplitView isSubviewCollapsed:_chartView] forSegment:2];

  [_middleShowHideControl setSelected:
   ![_middleSplitView isSubviewCollapsed:_lapView] forSegment:0];
  [_middleShowHideControl setEnabled:
   ![_mainSplitView isSubviewCollapsed:_middleSplitView]];
}

- (void)loadView
{
  [super loadView];
  [self viewDidLoad];
}

// NSSplitViewDelegate methods

- (BOOL)splitView:(NSSplitView *)view canCollapseSubview:(NSView *)subview
{
  return YES;
}

- (BOOL)splitView:(NSSplitView *)view shouldCollapseSubview:(NSView *)subview
    forDoubleClickOnDividerAtIndex:(NSInteger)idx
{
  return YES;
}

- (CGFloat)splitView:(NSSplitView *)view constrainMinCoordinate:(CGFloat)p
    ofSubviewAt:(NSInteger)idx
{
  NSView *subview = [[view subviews] objectAtIndex:idx];
  CGFloat min_size = [(ActActivitySplitView *)view minimumSizeOfSubview:subview];

  return p + min_size;
}

- (CGFloat)splitView:(NSSplitView *)view constrainMaxCoordinate:(CGFloat)p
    ofSubviewAt:(NSInteger)idx
{
  NSView *subview = [[view subviews] objectAtIndex:idx];
  CGFloat min_size = [(ActActivitySplitView *)view minimumSizeOfSubview:subview];

  return p - min_size;
}

- (BOOL)splitView:(NSSplitView *)view
    shouldAdjustSizeOfSubview:(NSView *)subview
{
  if ([view isKindOfClass:[ActActivitySplitView class]])
    return [(ActActivitySplitView *)view shouldAdjustSizeOfSubview:subview];
  else
    return YES;
}

@end
