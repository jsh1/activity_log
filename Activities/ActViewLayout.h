// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

@interface NSView (ActViewLayout)

// base implementation returns bounds.size.height. */

- (CGFloat)heightForWidth:(CGFloat)width;

// should be called on super when -heightForWidth: result may have changed

- (void)subviewNeedsLayout:(NSView *)subview;

// should not be called directly, only for subclasses to override

- (void)layoutSubviews;

@end
