// -*- c-style: gnu -*-

#import "ActHorizontalBoxView.h"

@implementation ActHorizontalBoxView

- (CGFloat)heightForWidth:(CGFloat)w
{
  CGFloat h = 0;

  for (NSView *subview in [self subviews])
    {
      CGFloat hh = [subview frame].size.height;
      if (h < hh)
	h = hh;
    }

  return h;
}

- (void)layoutSubviews
{
  NSRect bounds = [self bounds];
  CGFloat x = 0;

  for (NSView *subview in [self subviews])
    {
      CGFloat w = [subview preferredWidth];

      NSRect old_frame = [subview frame];

      NSRect new_frame;
      if (!_rightToLeft)
	new_frame.origin.x = bounds.origin.x + x;
      else
	new_frame.origin.x = bounds.origin.x + bounds.size.width - (x + w);
      new_frame.origin.y = old_frame.origin.y;
      new_frame.size.width = w;
      new_frame.size.height = old_frame.size.height;

      if (!NSEqualRects(old_frame, new_frame))
	[subview setFrame:new_frame];

      x += w + _spacing;
    }
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
  [self layoutSubviews];
}

@end

@implementation NSView (ActHorizontalBoxView)

- (CGFloat)preferredWidth
{
  return [self frame].size.width;
}

@end
