// -*- c-style: gnu -*-

#import "ActActivitySummaryView.h"

#import "ActActivityView.h"
#import "ActExpandableTextField.h"
#import "ActHorizontalBoxView.h"

#define MIN_HEIGHT 250

@implementation ActActivitySummaryView

+ (NSString *)nibName
{
  return @"ActActivitySummaryView";
}

- (void)awakeFromNib
{
  NSColor *color = [NSColor colorWithDeviceWhite:.4 alpha:1];
  [_dateTextField setTextColor:color];
  [_activityTextField setTextColor:color];
  [_typeTextField setTextColor:color];

  color = [NSColor colorWithDeviceWhite:.1 alpha:1];
  [_courseTextField setTextColor:color];
  [_bodyTextView setTextColor:color];
}

- (void)activityDidChange
{
  ActActivityView *view = [self activityView];

  [_dateTextField setStringValue:[view stringForField:@"date"]];
  [_activityTextField setStringValue:[view stringForField:@"activity"]];
  [_typeTextField setStringValue:[view stringForField:@"type"]];
  [_courseTextField setStringValue:[view stringForField:@"course"]];
  [_bodyTextView setString:[view bodyString]];

#if 0
  if (const act::activity *a = [[self activityView] activity])
    {
      
    }
#endif
}

- (void)activityDidChangeField:(NSString *)name
{
}

- (void)activityDidChangeBody
{
}

- (void)selectedLapDidChange
{
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
  return MIN_HEIGHT;
}

- (NSInteger)preferredNumberOfColumns
{
  return 7;
}

- (void)layoutSubviews
{
}

- (void)drawRect:(NSRect)r
{
  [self drawBackgroundRect:r];
  [self drawBorderRect:r];
}

- (IBAction)controlAction:(id)sender
{
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

      [[self activityView] setBodyString:[_bodyTextView string]];
    }
}

- (void)textDidChange:(NSNotification *)note
{
  if ([note object] == _bodyTextView)
    {
    }
}

@end
