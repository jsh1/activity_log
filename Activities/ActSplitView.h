// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

@interface ActSplitView : NSSplitView
{
@private
  NSView *_collapsingSubview;
}

- (NSDictionary *)savedViewState;
- (void)applySavedViewState:(NSDictionary *)dict;

- (void)setSubview:(NSView *)subview collapsed:(BOOL)flag;

- (BOOL)shouldAdjustSizeOfSubview:(NSView *)subview;

- (CGFloat)minimumSizeOfSubview:(NSView *)subview;

@end

@interface NSView (ActSplitView)

- (CGFloat)minSize;

@end
