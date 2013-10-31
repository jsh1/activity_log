// -*- c-style: gnu -*-

#import "ActSummaryViewController.h"

#import "ActAppDelegate.h"
#import "ActCollapsibleView.h"
#import "ActColor.h"
#import "ActHorizontalBoxView.h"
#import "ActViewLayout.h"
#import "ActWindowController.h"

#import "act-database.h"

#import "ActFoundationExtensions.h"

#define BODY_X_INSET 6
#define BODY_Y_INSET 10
#define BODY_SPACING 8
#define BODY_BOTTOM_BORDER 14
#define MIN_BODY_HEIGHT 42

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

  [(ActCollapsibleView *)[self view] setTitle:@"Summary & Notes"];
  [(ActCollapsibleView *)[self view] setHeaderInset:10];

  // creating layers for each subview is not gaining us anything
  [[self view] setCanDrawSubviewsIntoLayer:YES];

  [_dateBox setRightToLeft:YES];
  [_dateBox setSpacing:1];
  [_typeBox setSpacing:3];
  [_typeBox setRightToLeft:YES];
  [_statsBox setSpacing:8];

  _bodyTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 500, 32)];
  [_bodyTextView setAllowsUndo:YES];
  [_bodyTextView setRichText:NO];
  [_bodyTextView setUsesFontPanel:NO];
  [_bodyTextView setImportsGraphics:NO];
  [_bodyTextView setDrawsBackground:NO];
  [_bodyTextView setFont:[NSFont fontWithName:@"Helvetica" size:12]];
  [_bodyTextView setTextColor:[ActColor controlTextColor]];
  [_bodyTextView setDelegate:self];
  [_summaryView addSubview:_bodyTextView];
  [_bodyTextView release];

  _bodyLayoutContainer = [[NSTextContainer alloc]
			  initWithContainerSize:NSZeroSize];
  [_bodyLayoutContainer setLineFragmentPadding:0];
  _bodyLayoutManager = [[NSLayoutManager alloc] init];
  [_bodyLayoutManager addTextContainer:_bodyLayoutContainer];
  [[_bodyTextView textStorage] addLayoutManager:_bodyLayoutManager];

  [_courseField setCompletesEverything:YES];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [_bodyTextView setDelegate:nil];
  [_bodyLayoutManager release];
  [_bodyLayoutContainer release];

  [_fieldControls release];

  [super dealloc];
}

- (NSView *)initialFirstResponder
{
  return _courseField;
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

- (CGFloat)heightOfView:(NSView *)view forWidth:(CGFloat)width
{
  if (view == _summaryView)
    {
      // See https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html
 
      [_bodyLayoutContainer setContainerSize:
       NSMakeSize(width - BODY_X_INSET*2, CGFLOAT_MAX)];
      [_bodyLayoutManager glyphRangeForTextContainer:_bodyLayoutContainer];
 
      CGFloat body_height = ([_bodyLayoutManager usedRectForTextContainer:
			      _bodyLayoutContainer].size.height
			     + BODY_BOTTOM_BORDER);
      body_height = std::max(ceil(body_height), (CGFloat)MIN_BODY_HEIGHT);

      NSRect r = NSUnionRect([_statsBox frame], [_courseField frame]);
      r.size.height += BODY_SPACING + body_height;

      return r.size.height;
    }
  else
    return [view heightForWidth:width];
}

- (void)layoutSubviewsOfView:(NSView *)view
{
  if (view == _summaryView)
    {
      [_dateBox layoutSubviews];
      [_typeBox layoutSubviews];
      [_statsBox layoutSubviews];

      NSRect bounds = [view bounds];
      NSRect top = NSUnionRect([_statsBox frame], [_courseField frame]);

      NSRect frame;
      frame.origin.x = bounds.origin.x + BODY_X_INSET;
      frame.origin.y = bounds.origin.y + BODY_Y_INSET;
      frame.size.width = bounds.size.width - BODY_X_INSET*2;
      frame.size.height = (top.origin.y - BODY_SPACING) - frame.origin.y;
      [_bodyTextView setFrame:frame];
    }
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

  [self layoutSubviewsOfView:_summaryView];
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  [self _reloadFields];
}

- (void)activityDidChangeField:(NSNotification *)note
{
  if (_ignoreChanges != 0)
    return;

  void *ptr = [[[note userInfo] objectForKey:@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);

  if (a == [_controller selectedActivityStorage])
    [self _reloadFields];
}

- (void)activityDidChangeBody:(NSNotification *)note
{
  if (_ignoreChanges != 0)
    return;

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

- (void)textDidChange:(NSNotification *)note
{
  if ([note object] == _bodyTextView)
    {
      // FIXME: this might be too slow?
 
      NSRect bounds = [_summaryView bounds];
      if ([self heightOfView:_summaryView
	   forWidth:bounds.size.width] != bounds.size.height)
	[[_summaryView superview] subviewNeedsLayout:_summaryView];

      _ignoreChanges++;
      [_controller setBodyString:[_bodyTextView string]];
      _ignoreChanges--;
    }
}

- (void)textDidEndEditing:(NSNotification *)note
{
  if ([note object] == _bodyTextView)
    {
      [_controller setBodyString:[_bodyTextView string]];
    }
}

@end

@implementation ActSummaryView

- (void)drawRect:(NSRect)r
{
  [[ActColor controlBackgroundColor] setFill];
  [NSBezierPath fillRect:r];
}

@end
