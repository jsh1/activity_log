// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

@interface ActActivitySplitView : NSSplitView
{
@private
  NSView *_collapsingSubview;
}

- (void)setSubview:(NSView *)subview collapsed:(BOOL)flag;

- (BOOL)shouldAdjustSizeOfSubview:(NSView *)subview;

- (CGFloat)minimumSizeOfSubview:(NSView *)subview;

@end

@interface NSView (ActActivitySplitView)

- (CGFloat)minSize;

@end
