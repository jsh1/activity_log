// -*- c-style: gnu -*-

#import "ActActivitySplitView.h"

@implementation ActActivitySplitView

- (void)setSubview:(NSView *)subview collapsed:(BOOL)flag
{
  if (flag != [subview isHidden])
    {
      [subview setHidden:flag];

      _collapsingSubview = subview;
      [self adjustSubviews];
      _collapsingSubview = nil;
    }
}

- (BOOL)shouldAdjustSizeOfSubview:(NSView *)subview
{
  if (_collapsingSubview != nil)
    {
      if (subview == _collapsingSubview)
	return NO;

      // If more than two subviews, only move those adjacent to the
      // [un]collapsing view.

      NSArray *subviews = [self subviews];
      NSInteger idx1 = [subviews indexOfObjectIdenticalTo:_collapsingSubview];
      NSInteger idx2 = [subviews indexOfObjectIdenticalTo:subview];

      if (abs(idx1 - idx2) > 1)
	return NO;
    }

  return YES;
}

- (CGFloat)minimumSizeOfSubview:(NSView *)subview
{
  if ([subview respondsToSelector:@selector(minSize)])
    return [subview minSize];
  else
    return 100;
}

@end
