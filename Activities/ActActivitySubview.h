// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

@class ActActivityView;

@interface ActActivitySubview : NSView
{
  IBOutlet ActActivityView *_activityView;
}

// Standard implementation returns nil

+ (NSString *)nibName;

// Standard implementation loads nib if non-nil, else alloc/inits

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

// For horizontal box views. Max of twelve columns. Standard
// implementation returns zero.

- (NSInteger)preferredNumberOfColumns;

// Standard implementation does nothing

- (void)layoutSubviews;

- (void)drawBackgroundRect:(NSRect)r;
- (void)drawBorderRect:(NSRect)r;

@end
