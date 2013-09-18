// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

@interface ActHorizontalBoxView : NSView

- (void)layoutSubviews;

@end

@interface NSView (ActHorizontalBoxView)

- (CGFloat)preferredWidth;

@end
