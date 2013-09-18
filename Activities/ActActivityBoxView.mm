// -*- c-style: gnu -*-

#import "ActActivityBoxView.h"

#import "ActActivityView.h"

#define SUBVIEW_X_SPACING 4
#define SUBVIEW_Y_SPACING 4

#define COLUMNS 12

@implementation ActActivityBoxView

- (void)activityDidChange
{
  for (ActActivitySubview *subview in [self subviews])
    [subview activityDidChange];
}

- (void)activityDidChangeField:(NSString *)name
{
  for (ActActivitySubview *subview in [self subviews])
    [subview activityDidChangeField:name];
}

- (void)activityDidChangeBody
{
  for (ActActivitySubview *subview in [self subviews])
    [subview activityDidChangeBody];
}

- (void)selectedLapDidChange
{
  for (ActActivitySubview *subview in [self subviews])
    [subview selectedLapDidChange];
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
  NSArray *subviews = [self subviews];
  NSInteger count = [subviews count];
  if (count == 0)
    return 0;

  CGFloat y = 0;

  for (ActActivitySubview *subview in [self subviews])
    {
      NSEdgeInsets insets = [subview edgeInsets];

      CGFloat width1 = width;

      if (!_vertical)
	{
	  NSInteger cols = [subview preferredNumberOfColumns];
	  if (cols != 0)
	    width1 = floor(width / COLUMNS * cols);
	  else
	    width1 = floor((width - SUBVIEW_X_SPACING * (count - 1)) / count);
	}

      CGFloat sub_width = width1 - (insets.left + insets.right);
      CGFloat sub_height = [subview preferredHeightForWidth:sub_width];

      if (sub_width > 0 && sub_height > 0)
	{
	  CGFloat h = insets.top + sub_height + insets.bottom;
	  if (_vertical)
	    {
	      if (y > 0)
		y += SUBVIEW_Y_SPACING;
	      y += h;
	    }
	  else
	    y = std::max(y, h);
	}
    }

  return y;
}

- (void)layoutSubviews
{
  NSArray *subviews = [self subviews];
  NSInteger count = [subviews count];
  if (count == 0)
    return;

  NSRect bounds = [self bounds];
  CGFloat x = bounds.origin.x;
  CGFloat y = bounds.origin.y;
  CGFloat width = bounds.size.width;

  for (ActActivitySubview *subview in subviews)
    {
      NSEdgeInsets insets = [subview edgeInsets];

      CGFloat width1 = width;

      if (!_vertical)
	{
	  NSInteger cols = [subview preferredNumberOfColumns];
	  if (cols != 0)
	    width1 = floor(width / COLUMNS * cols);
	  else
	    width1 = floor((width - SUBVIEW_X_SPACING * (count - 1)) / count);
	}

      CGFloat sub_width = width1 - (insets.left + insets.right);
      CGFloat sub_height = _vertical ? [subview preferredHeightForWidth:sub_width] : bounds.size.height - (insets.top + insets.bottom);

      if (sub_width > 0 && sub_height > 0)
	{
	  NSRect frame;
	  frame.origin.x = x + insets.left;
	  frame.origin.y = y + insets.top;
	  frame.size.width = sub_width;
	  frame.size.height = sub_height;

	  [subview setHidden:NO];
	  [subview setFrame:frame];
	  [subview layoutSubviews];

	  if (_vertical)
	    y += insets.top + sub_height + insets.bottom + SUBVIEW_Y_SPACING;
	  else
	    x += width1 + SUBVIEW_X_SPACING;
	}
      else
	[subview setHidden:YES];
    }
}

- (BOOL)isFlipped
{
  return YES;
}

@end
