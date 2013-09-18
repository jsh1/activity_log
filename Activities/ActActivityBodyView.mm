// -*- c-style: gnu -*-

#import "ActActivityBodyView.h"

#import "ActActivityView.h"

#import <algorithm>

#define TOP_BORDER 0
#define BOTTOM_BORDER 0
#define LEFT_BORDER 32
#define RIGHT_BORDER 32

#define MAX_WIDTH 540

@implementation ActActivityBodyView

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self == nil)
    return nil;

  _textView = [[NSTextView alloc] initWithFrame:NSZeroRect];
  [_textView setDrawsBackground:NO];
  [_textView setDelegate:self];
  [self addSubview:_textView];
  [_textView release];

  _layoutContainer = [[NSTextContainer alloc]
		      initWithContainerSize:NSZeroSize];
  [_layoutContainer setLineFragmentPadding:0];
  _layoutManager = [[NSLayoutManager alloc] init];
  [_layoutManager addTextContainer:_layoutContainer];
  [[_textView textStorage] addLayoutManager:_layoutManager];

  return self;
}

- (void)dealloc
{
  [_textView setDelegate:nil];

  [_layoutManager release];
  [_layoutContainer release];

  [super dealloc];
}

- (void)activityDidChange
{
  ActActivityView *view = [self activityView];
  [_textView setFont:[view font]];
  [_textView setString:[view bodyString]];
}

- (NSEdgeInsets)edgeInsets
{
  return NSEdgeInsetsMake(TOP_BORDER, LEFT_BORDER,
			  BOTTOM_BORDER, RIGHT_BORDER);
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
  // See https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html

  width = std::min(width, (CGFloat) MAX_WIDTH);

  [_layoutContainer setContainerSize:NSMakeSize(width, CGFLOAT_MAX)];
  [_layoutManager glyphRangeForTextContainer:_layoutContainer];

  return ceil([_layoutManager usedRectForTextContainer:_layoutContainer].size.height);
}

- (void)layoutSubviews
{
  NSRect bounds = [self bounds];

  NSRect frame = NSMakeRect(0, 0, bounds.size.width, bounds.size.height);
  frame.size.width = std::min(frame.size.width, (CGFloat) MAX_WIDTH);

  [_textView setFrame:frame];
}

// NSTextViewDelegate methods

- (void)textDidChange:(NSNotification *)note
{
  if ([note object] == _textView)
    {
      // FIXME: this might be too slow?

      NSRect bounds = [self bounds];
      CGFloat width = std::min(bounds.size.width, (CGFloat) MAX_WIDTH);
      if ([self preferredHeightForWidth:width] != bounds.size.height)
	[[self activityView] updateHeight];
    }
}

- (void)textDidEndEditing:(NSNotification *)note
{
  if ([note object] == _textView)
    {
      [[self activityView] setBodyString:[_textView string]];
    }
}

@end
