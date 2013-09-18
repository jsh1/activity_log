// -*- c-style: gnu -*-

#import "ActActivitySummaryView.h"

#import "ActActivityViewController.h"
#import "ActExpandableTextField.h"
#import "ActHorizontalBoxView.h"

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
  ActActivityViewController *controller = [self controller];

  [_dateTextField setStringValue:[controller stringForField:@"date"]];
  [_activityTextField setStringValue:[controller stringForField:@"activity"]];
  [_typeTextField setStringValue:[controller stringForField:@"type"]];
  [_courseTextField setStringValue:[controller stringForField:@"course"]];
  [_bodyTextView setString:[controller bodyString]];

#if 0
  if (const act::activity *a = [controller activity])
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

- (CGSize)preferredSize
{
  return CGSizeMake(400, 200);
}

- (void)layoutSubviews
{
}

- (void)drawRect:(NSRect)r
{
  [self drawBackgroundRect:r];
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
