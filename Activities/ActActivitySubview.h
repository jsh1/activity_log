// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

@class ActActivityView;

@interface ActActivitySubview : NSView
{
  IBOutlet ActActivityView *_activityView;
}

@property(nonatomic, assign) ActActivityView *activityView;

// Standard implementations do nothing

- (void)activityDidChange;
- (void)selectedLapDidChange;

// Standard implementation returns all zeros

- (NSEdgeInsets)edgeInsets;

// Standard implementation returns zero

- (CGFloat)preferredHeightForWidth:(CGFloat)width;

// Standard implementation does nothing

- (void)layoutSubviews;

@end
