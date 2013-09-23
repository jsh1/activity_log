// -*- c-style: gnu -*-

#import "ActActivitySummaryView.h"

#import "ActActivityHeaderView.h"
#import "ActActivityViewController.h"
#import "ActActivityTextField.h"
#import "ActHorizontalBoxView.h"
#import "ActWindowController.h"

#import "act-database.h"

#import "ActFoundationExtensions.h"

#define CORNER_RADIUS 6

@implementation ActActivitySummaryView

- (void)dealloc
{
  [_fieldControls release];

  [super dealloc];
}

- (void)awakeFromNib
{
  [_dateBox setRightToLeft:YES];
  [_dateBox setSpacing:3];
  [_typeBox setSpacing:3];
  [_statsBox setSpacing:8];
  [_courseField setCompletesEverything:YES];
}

- (CGFloat)minSize
{
  return 180;
}

+ (NSColor *)textFieldColor:(BOOL)readOnly
{
  static NSColor *a, *b;

  if (a == nil)
    {
      a = [[NSColor colorWithDeviceWhite:.25 alpha:1] retain];
      b = [[NSColor colorWithDeviceWhite:.45 alpha:1] retain];
    }

  return !readOnly ? a : b;
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
  ActActivityViewController *controller = [self controller];

  if ([controller activity] != nullptr)
    {
      NSDate *date = [controller dateField];
      NSDateFormatter *formatter = [[NSDateFormatter alloc] init];

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
	  NSString *string = [controller stringForField:field];
	  NSTextField *control = [dict objectForKey:field];
	  [control setStringValue:string];
	  BOOL readOnly = [controller isFieldReadOnly:field];
	  [control setEditable:!readOnly];
	  [control setTextColor:[[self class] textFieldColor:readOnly]];
	}

      [_bodyTextView setString:[controller bodyString]];
    }
  else
    {
      [_dateDateField setObjectValue:nil];
      [_dateDayField setObjectValue:nil];
      [_dateTimeField setObjectValue:nil];

      NSDictionary *dict = [self fieldControls];
      NSColor *color = [[self class] textFieldColor:YES];

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

- (void)_updateHeaderFields
{
  const act::activity *a = [[self controller] activity];

  [_headerView setDisplayedFields:[NSArray array]];

  if (a != nullptr)
    {
      if (a->average_hr() != 0)
	[_headerView addDisplayedField:@"Average-HR"];
      if (a->max_hr() != 0)
	[_headerView addDisplayedField:@"Max-HR"];

      if (a->vdot() != 0)
	[_headerView addDisplayedField:@"VDOT"];
      if (a->points() != 0)
	[_headerView addDisplayedField:@"Points"];

      if (a->effort() != 0)
	[_headerView addDisplayedField:@"Effort"];
      if (a->quality() != 0)
	[_headerView addDisplayedField:@"Quality"];

      if (a->calories() != 0)
	[_headerView addDisplayedField:@"Calories"];
      if (a->weight() != 0)
	[_headerView addDisplayedField:@"Weight"];
      if (a->resting_hr() != 0)
	[_headerView addDisplayedField:@"Resting-HR"];

      if (a->temperature() != 0)
	[_headerView addDisplayedField:@"Temperature"];
      if (a->dew_point() != 0)
	[_headerView addDisplayedField:@"Dew-Point"];
      if (a->field_ptr("weather") != nullptr)
	[_headerView addDisplayedField:@"Weather"];

      if (a->field_ptr("equipment") != nullptr)
	[_headerView addDisplayedField:@"Equipment"];

      NSArray *ignoredFields = @[@"Date", @"Activity", @"Type", @"Course",
	@"Distance", @"Duration", @"Pace", @"Speed", @"GPS-File"];

      for (const auto &it : *a->storage())
	{
	  NSString *str = [[NSString alloc]
			   initWithUTF8String:it.first.c_str()];
	  if (![_headerView displaysField:str]
	      && ![ignoredFields containsStringNoCase:str])
	    [_headerView addDisplayedField:str];
	  [str release];
	}
    }

  [_headerView layoutAndResize];
}

- (void)activityDidChange
{
  [self _reloadFields];
  [self _updateHeaderFields];

  [super activityDidChange];
}

- (void)activityDidChangeField:(NSString *)name
{
  [self _reloadFields];

  [super activityDidChangeField:name];
}

- (void)activityDidChangeBody
{
  [_bodyTextView setString:[[self controller] bodyString]];

  [super activityDidChangeBody];
}

- (void)drawRect:(NSRect)r
{
  NSRect rect = NSInsetRect([self bounds], 5, 5);
  rect.origin.y += 2;

  CGContextRef ctx = (CGContextRef) [[NSGraphicsContext
				      currentContext] graphicsPort];
  CGContextSaveGState(ctx);

  static CGColorRef shadow_color;

  if (shadow_color == nullptr)
    {
      const CGFloat comp[2] = {0, .5};
      CGColorSpaceRef space = CGColorSpaceCreateDeviceGray();
      shadow_color = CGColorCreate(space, comp);
      CGColorSpaceRelease(space);
    }

  CGContextSetShadowWithColor(ctx, CGSizeMake(0, -1), 2.5, shadow_color);

  [[NSColor whiteColor] setFill];
  [[NSBezierPath bezierPathWithRoundedRect:rect
    xRadius:CORNER_RADIUS yRadius:CORNER_RADIUS] fill];

  CGContextRestoreGState(ctx);
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
	  [[self controller] setString:[sender stringValue]
	   forField:fieldName];
	  return;
	}
    }

  if (sender == _dateTimeField || sender == _dateDateField)
    {
      NSString *str = [NSString stringWithFormat:@"%@ %@",
		       [_dateDateField stringValue],
		       [_dateTimeField stringValue]];

      NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
      [formatter setDateStyle:NSDateFormatterShortStyle];
      [formatter setTimeStyle:NSDateFormatterShortStyle];

      // FIXME: mark invalid dates somehow?

      if (NSDate *date = [formatter dateFromString:str])
	[[self controller] setDateField:date];

      [formatter release];
      return;
    }
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
  [super resizeSubviewsWithOldSize:oldSize];
  [self _reflowFields];
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

      act::database *db = [[[self controller] controller] database];

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
      [[self controller] setBodyString:[_bodyTextView string]];
    }
}

@end
