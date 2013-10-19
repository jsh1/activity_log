// -*- c-style: gnu -*-

#import "ActViewLayout.h"

@implementation NSView (ActLayout)

- (CGFloat)heightForWidth:(CGFloat)width
{
  return [self bounds].size.height;
}

- (void)subviewNeedsLayout:(NSView *)view
{
  // containers will override this and either call super or resize
  // themselves.

  if (NSView *superview = [self superview])
    [superview subviewNeedsLayout:self];
  else
    [self layoutSubviews];
}

- (void)layoutSubviews
{
  NSLog(@"warning: -layoutSubviews: not implemented by %@",
	NSStringFromClass([self class]));
}

@end
