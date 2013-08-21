// -*- c-style: gnu -*-

#import "ActActivityBodyView.h"

#import "ActActivityView.h"

#define LEFT_BORDER_WIDTH 32
#define RIGHT_BORDER_WIDTH 32

@implementation ActActivityBodyView

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self == nil)
    return nil;

  _textView = [[NSTextView alloc] initWithFrame:NSZeroRect];
  [_textView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
  [self addSubview:_textView];
  [_textView release];
  [_textView setDrawsBackground:NO];

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

	  return str;
	}
    }

  return @"";
}

- (void)setBodyString:(NSString *)str
{
  // FIXME: implement this
}

- (void)activityDidChange
{
  [_textView setString:[self bodyString]];
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
  // See https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html

  width = width - (LEFT_BORDER_WIDTH + RIGHT_BORDER_WIDTH);
  if (width < 0)
    width = 0;

  [_layoutContainer setContainerSize:NSMakeSize(width, CGFLOAT_MAX)];
  [_layoutManager glyphRangeForTextContainer:_layoutContainer];

  return [_layoutManager usedRectForTextContainer:_layoutContainer].size.height;
}

- (void)layoutSubviews
{
  NSRect bounds = [self bounds];
  NSRect frame = NSMakeRect(LEFT_BORDER_WIDTH, 0, bounds.size.width
			    - (LEFT_BORDER_WIDTH + RIGHT_BORDER_WIDTH),
			    bounds.size.height);

  [_textView setFrame:frame];
}

@end
