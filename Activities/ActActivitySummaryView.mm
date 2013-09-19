// -*- c-style: gnu -*-

#import "ActActivitySummaryView.h"

#import "ActActivityHeaderView.h"
#import "ActActivityViewController.h"
#import "ActExpandableTextField.h"
#import "ActHorizontalBoxView.h"

#import "ActFoundationExtensions.h"

#define CORNER_RADIUS 6

@implementation ActActivitySummaryView

- (void)awakeFromNib
{
  [_dateBox setRightToLeft:YES];
  [_dateBox setSpacing:4];
  [_typeBox setSpacing:4];
  [_statsBox setSpacing:6];
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

  if (const act::activity *a = [controller activity])
    {
      NSDate *date = [NSDate dateWithTimeIntervalSince1970:a->date()];
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

      [_typeActivityField setStringValue:[[controller stringForField:@"activity"] capitalizedString]];
      [_typeTypeField setStringValue:[controller stringForField:@"type"]];

      [_statsDistanceField setStringValue:[controller stringForField:@"distance"]];
      [_statsDurationField setStringValue:[controller stringForField:@"duration"]];
      [_statsPaceField setStringValue:[controller stringForField:@"pace"]];

      [_courseField setStringValue:[controller stringForField:@"course"]];
      [_bodyTextView setString:[controller bodyString]];
    }
  else
    {
      [_dateDateField setObjectValue:nil];
      [_dateDayField setObjectValue:nil];
      [_dateTimeField setObjectValue:nil];
      [_typeActivityField setObjectValue:nil];
      [_typeTypeField setObjectValue:nil];
      [_statsDistanceField setObjectValue:nil];
      [_statsDurationField setObjectValue:nil];
      [_statsPaceField setObjectValue:nil];
      [_courseField setObjectValue:nil];
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
      if (a->resting_hr() != 0)
	[_headerView addDisplayedField:@"Resting-HR"];
      if (a->average_hr() != 0)
	[_headerView addDisplayedField:@"Average-HR"];
      if (a->max_hr() != 0)
	[_headerView addDisplayedField:@"Max-HR"];

      if (a->points() != 0)
	[_headerView addDisplayedField:@"Points"];
      if (a->effort() != 0)
	[_headerView addDisplayedField:@"Effort"];
      if (a->quality() != 0)
	[_headerView addDisplayedField:@"Quality"];

      if (a->weight() != 0)
	[_headerView addDisplayedField:@"Weight"];
      if (a->calories() != 0)
	[_headerView addDisplayedField:@"Calories"];

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

- (CGSize)preferredSize
{
  return CGSizeMake(400, 200);
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
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
  [super resizeSubviewsWithOldSize:oldSize];
  [self _reflowFields];
}

// NSTextViewDelegate methods

- (void)textDidBeginEditing:(NSNotification *)note
{
  if ([note object] == _bodyTextView)
    {
      [_bodyTextView setDrawsBackground:YES];
    }
}

- (void)textDidEndEditing:(NSNotification *)note
{
  if ([note object] == _bodyTextView)
    {
      [_bodyTextView setDrawsBackground:NO];

      [[self controller] setBodyString:[_bodyTextView string]];
    }
}

- (void)textDidChange:(NSNotification *)note
{
  if ([note object] == _bodyTextView)
    {
    }
}

@end
