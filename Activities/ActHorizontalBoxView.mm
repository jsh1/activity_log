// -*- c-style: gnu -*-

#import "ActHorizontalBoxView.h"

@implementation ActHorizontalBoxView

- (void)layoutSubviews
{
  NSRect bounds = [self bounds];
  CGFloat x = bounds.origin.x;

  for (NSView *subview in [self subviews])
    {
      NSRect r = [subview frame];
      CGFloat w = [subview preferredWidth];

      if (r.origin.x != x || r.size.width != w)
	{
	  r.origin.x = x;
	  r.size.width = w;
	  [subview setFrame:r];
	}

      x += r.size.width;
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
