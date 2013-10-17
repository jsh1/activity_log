// -*- c-style: gnu -*-

#import "ActSummaryViewController.h"

#import "ActAppDelegate.h"
#import "ActColor.h"
#import "ActHorizontalBoxView.h"
#import "ActWindowController.h"

#import "act-database.h"

#import "ActFoundationExtensions.h"

#define CORNER_RADIUS 6

@implementation ActSummaryViewController

+ (NSString *)viewNibName
{
  return @"ActSummaryView";
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:_controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeField:)
   name:ActActivityDidChangeField object:_controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeBody:)
   name:ActActivityDidChangeBody object:_controller];

  [_dateBox setRightToLeft:YES];
  [_dateBox setSpacing:3];
  [_typeBox setSpacing:3];
  [_statsBox setSpacing:8];

  [_bodyTextView setFont:[NSFont fontWithName:@"Helvetica" size:12]];

  [_courseField setCompletesEverything:YES];
}

- (NSView *)initialFirstResponder
{
  return _typeActivityField;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [_fieldControls release];

  [super dealloc];
}

- (NSDictionary *)fieldControls
{
  if (_fieldControls == nil)
    {
      _fieldControls = [[NSDictionary alloc] initWithObjectsAndKeys:
			_typeActivityField, @"activity",
			_typeTypeField, @"type",
			_statsDistanceField, @"distance",
			_statsDurationField, @"duration",
			_statsPaceField, @"pace",
			_courseField, @"course",
			nil];
    }

  return _fieldControls;
}

- (void)_reflowFields
{
  [_dateBox layoutSubviews];
  [_typeBox layoutSubviews];
  [_statsBox layoutSubviews];
}

- (void)_reloadFields
{
  if ([_controller selectedActivity] != nullptr)
    {
      NSDate *date = [_controller dateField];
      NSDateFormatter *formatter = [[NSDateFormatter alloc] init];

      [formatter setLocale:[(ActAppDelegate *)[NSApp delegate] currentLocale]];
      [formatter setDateStyle:NSDateFormatterShortStyle];
      [formatter setTimeStyle:NSDateFormatterNoStyle];
      [_dateDateField setStringValue:[formatter stringFromDate:date]];

      NSInteger day = [[[NSCalendar currentCalendar] components:
			NSWeekdayCalendarUnit fromDate:date] weekday];
      [_dateDayField setStringValue:
       [NSString stringWithFormat:@"on %@",
	[[formatter weekdaySymbols] objectAtIndex:day - 1]]];

      [formatter setDateStyle:NSDateFormatterNoStyle];
      [formatter setTimeStyle:NSDateFormatterShortStyle];
      [_dateTimeField setStringValue:[formatter stringFromDate:date]];

      [formatter release];

      NSDictionary *dict = [self fieldControls];
      for (NSString *field in dict)
	{
	  NSString *string = [_controller stringForField:field];
	  NSTextField *control = [dict objectForKey:field];
	  [control setStringValue:string];
	  BOOL readOnly = [_controller isFieldReadOnly:field];
	  [control setEditable:!readOnly];
	  NSColor *color;
	  if ([control superview] != _statsBox)
	    color = [ActColor controlTextColor:readOnly];
	  else
	    color = [ActColor controlDetailTextColor:readOnly];
	  [control setTextColor:color];
	}

      [_bodyTextView setString:[_controller bodyString]];
    }
  else
    {
      [_dateDateField setObjectValue:nil];
      [_dateDayField setObjectValue:nil];
      [_dateTimeField setObjectValue:nil];

      NSDictionary *dict = [self fieldControls];
      NSColor *color = [ActColor disabledControlTextColor];

      for (NSString *field in dict)
	{
	  NSTextField *control = [dict objectForKey:field];

	  [control setObjectValue:nil];
	  [control setEditable:NO];
	  [control setTextColor:color];
	}

      [_bodyTextView setString:@""];
    }

  [self _reflowFields];
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  [self _reloadFields];
}

- (void)activityDidChangeField:(NSNotification *)note
{
  void *ptr = [[[note userInfo] objectForKey:@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);

  if (a == [_controller selectedActivityStorage])
    [self _reloadFields];
}

- (void)activityDidChangeBody:(NSNotification *)note
{
  void *ptr = [[[note userInfo] objectForKey:@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);

  if (a == [_controller selectedActivityStorage])
    [_bodyTextView setString:[_controller bodyString]];
}

- (IBAction)controlAction:(id)sender
{
  if (![sender isEditable])
    return;

  NSDictionary *dict = [self fieldControls];

  for (NSString *fieldName in dict)
    {
      if ([dict objectForKey:fieldName] == sender)
	{
	  [_controller setString:[sender stringValue] forField:fieldName];
	  return;
	}
    }

  if (sender == _dateTimeField || sender == _dateDateField)
    {
      NSString *str = [NSString stringWithFormat:@"%@ %@",
		       [_dateDateField stringValue],
		       [_dateTimeField stringValue]];

      NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
      [formatter setLocale:[(ActAppDelegate *)[NSApp delegate] currentLocale]];
      [formatter setDateStyle:NSDateFormatterShortStyle];
      [formatter setTimeStyle:NSDateFormatterShortStyle];

      // FIXME: mark invalid dates somehow?

      if (NSDate *date = [formatter dateFromString:str])
	[_controller setDateField:date];

      [formatter release];
      return;
    }
}

// NSControlTextEditingDelegate methods

- (BOOL)control:(NSControl *)control
    textShouldEndEditing:(NSText *)fieldEditor
{
  [self controlAction:control];
  return YES;
}

- (NSArray *)control:(NSControl *)control textView:(NSTextView *)textView
    completions:(NSArray *)words forPartialWordRange:(NSRange)charRange
    indexOfSelectedItem:(NSInteger *)index
{
  const char *field_name = nullptr;

  if (control == _typeTypeField)
    field_name = "Type";
  else if (control == _typeActivityField)
    field_name = "Activity";
  else if (control == _courseField)
    field_name = "Course";

  if (field_name != nullptr)
    {
      NSString *str = [[textView string] substringWithRange:charRange];

      act::database *db = [_controller database];

      std::vector<std::string> completions;
      db->complete_field_value(field_name, [str UTF8String], completions);

      NSMutableArray *array = [NSMutableArray array];
      for (const auto &it : completions)
	[array addObject:[NSString stringWithUTF8String:it.c_str()]];

      return array;
    }

  return nil;
}

// NSTextViewDelegate methods

- (void)textDidEndEditing:(NSNotification *)note
{
  if ([note object] == _bodyTextView)
    {
      [_controller setBodyString:[_bodyTextView string]];
    }
}

@end

@implementation ActSummaryView

- (CGFloat)minSize
{
  return 300;
}

- (void)drawRect:(NSRect)r
{
  [[ActColor controlBackgroundColor] setFill];
  [NSBezierPath fillRect:r];
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
  [super resizeSubviewsWithOldSize:oldSize];
  [_controller _reflowFields];
}

- (BOOL)isOpaque
{
  return YES;
}

@end
