// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

@interface ActHorizontalBoxView : NSView
{
  CGFloat _spacing;
  BOOL _rightToLeft;
}

@property(nonatomic) CGFloat spacing;
@property(nonatomic, getter=isRightToLeft) BOOL rightToLeft;

- (void)layoutSubviews;

@end

@interface NSView (ActHorizontalBoxView)

- (CGFloat)preferredWidth;

@end
