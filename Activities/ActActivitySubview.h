// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

@class ActActivityView;

@interface ActActivitySubview : NSView
{
  IBOutlet ActActivityView *_activityView;
}

+ (ActActivitySubview *)subviewForView:(ActActivityView *)view;

@property(nonatomic, assign) ActActivityView *activityView;

// Standard implementations do nothing

- (void)activityDidChange;
- (void)activityDidChangeField:(NSString *)name;
- (void)activityDidChangeBody;
- (void)selectedLapDidChange;

// Standard implementation returns all zeros

- (NSEdgeInsets)edgeInsets;

// Standard implementation returns zero

- (CGFloat)preferredHeightForWidth:(CGFloat)width;

// Standard implementation does nothing

- (void)layoutSubviews;

@end
