// -*- c-style: gnu -*-

#import "ActActivityBodyView.h"

#import "ActActivityView.h"

#import <algorithm>

#define TOP_BORDER 0
#define BOTTOM_BORDER 0
#define LEFT_BORDER 32
#define RIGHT_BORDER 32

#define MAX_WIDTH 540

#define WRAP_COLUMN 72

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

- (NSString *)bodyString
{
  if (const act::activity *a = [[self activityView] activity])
    {
      const std::string &s = a->body();

      if (s.size() != 0)
	{
	  NSMutableString *str = [[NSMutableString alloc] init];

	  const char *ptr = s.c_str();

	  while (const char *eol = strchr(ptr, '\n'))
	    {
	      NSString *tem = [[NSString alloc] initWithBytes:ptr
			       length:eol-ptr encoding:NSUTF8StringEncoding];
	      [str appendString:tem];
	      [tem release];
	      ptr = eol + 1;
	      if (eol[1] == '\n')
		[str appendString:@"\n\n"], ptr++;
	      else if (eol[1] != 0)
		[str appendString:@" "];
	    }

	  if (*ptr != 0)
	    {
	      NSString *tem = [[NSString alloc] initWithUTF8String:ptr];
	      [str appendString:tem];
	      [tem release];
	    }

	  return [str autorelease];
	}
    }

  return @"";
}

- (void)setBodyString:(NSString *)str
{
  static const char whitespace[] = " \t\n\f\r";

  const char *ptr = [str UTF8String];

  std::string wrapped;
  size_t column = 0;

  while (*ptr != 0)
    {
      ptr = ptr + strspn(ptr, whitespace);
      const char *word = ptr + strcspn(ptr, whitespace);

      if (word > ptr)
	{
	  if (column >= WRAP_COLUMN)
	    {
	      wrapped.push_back('\n');
	      column = 0;
	    }
	  else
	    {
	      wrapped.push_back(' ');
	      column++;
	    }

	  wrapped.append(ptr, word - ptr);
	  column += word - ptr;
	  ptr = word;
	}
    }

  if (column > 0)
    wrapped.push_back('\n');

  if (act::activity *a = [[self activityView] activity])
    {
      std::string &body = a->storage()->body();

      if (wrapped != body)
	{
	  // FIXME: undo management

	  std::swap(body, wrapped);
	  [[self activityView] activityDidChangeBody];
	}
    }
}

- (void)activityDidChange
{
  [_textView setFont:[[self activityView] font]];
  [_textView setString:[self bodyString]];
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

  return [_layoutManager usedRectForTextContainer:_layoutContainer].size.height;
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
      [self setBodyString:[_textView string]];
    }
}

@end
