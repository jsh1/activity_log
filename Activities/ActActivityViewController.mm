// -*- c-style: gnu -*-

#import "ActActivityViewController.h"

#import "ActActivitySubview.h"
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

// NSSplitViewDelegate methods

- (BOOL)splitView:(NSSplitView *)view canCollapseSubview:(NSView *)subview
{
  return YES;
}

- (BOOL)splitView:(NSSplitView *)view shouldCollapseSubview:(NSView *)subview
    forDoubleClickOnDividerAtIndex:(NSInteger)idx
{
  return [[view subviews] count] <= 2;
}

- (CGFloat)splitView:(NSSplitView *)view constrainMinCoordinate:(CGFloat)p
    ofSubviewAt:(NSInteger)idx
{
  return p + 64;
}

- (CGFloat)splitView:(NSSplitView *)view constrainMaxCoordinate:(CGFloat)p
    ofSubviewAt:(NSInteger)idx
{
  return p - 64;
}

@end
