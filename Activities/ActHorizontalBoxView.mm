// -*- c-style: gnu -*-

#import "ActHorizontalBoxView.h"

@implementation ActHorizontalBoxView

- (void)layoutSubviews
{
  NSRect bounds = [self bounds];
  CGFloat x = 0;

  for (NSView *subview in [self subviews])
    {
      CGFloat w = [subview preferredWidth];

      NSRect old_frame = [subview frame];
      NSRect new_frame = old_frame;

      if (!_rightToLeft)
	new_frame.origin.x = bounds.origin.x + x;
      else
	new_frame.origin.x = bounds.origin.x + bounds.size.width - (x + w);

      new_frame.size.width = w;

      if (!NSEqualRects(old_frame, new_frame))
	[subview setFrame:new_frame];

      x += w + _spacing;
    }
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
  [super resizeSubviewsWithOldSize:oldSize];
  [self layoutSubviews];
}

@end

@implementation NSView (ActHorizontalBoxView)

- (CGFloat)preferredWidth
{
  return [self frame].size.width;
}

@end
