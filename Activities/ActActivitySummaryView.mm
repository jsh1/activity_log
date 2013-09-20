// -*- c-style: gnu -*-

#import "ActActivitySummaryView.h"

#import "ActActivityHeaderView.h"
#import "ActActivityViewController.h"
#import "ActExpandableTextField.h"
#import "ActHorizontalBoxView.h"

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

	  if ([field isEqualToString:@"activity"])
	    string = [string capitalizedString];

	  BOOL readOnly = [controller isFieldReadOnly:field];
	  [control setStringValue:string];
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

  NSRect frame = [_headerView frame];
  CGFloat height = [_headerView preferredHeight];

  if (frame.size.height != height)
    {
      frame.size.height = height;
      [_headerView setFrame:frame];
    }

  [_headerView layoutSubviews];
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

// NSTextViewDelegate methods

- (void)textDidEndEditing:(NSNotification *)note
{
  if ([note object] == _bodyTextView)
    {
      [[self controller] setBodyString:[_bodyTextView string]];
    }
}

@end
