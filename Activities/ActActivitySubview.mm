// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

#import "ActActivityView.h"

@implementation ActActivitySubview

@synthesize activityView = _activityView;

+ (ActActivitySubview *)subviewForView:(ActActivityView *)view
{
  ActActivitySubview *subview = [[self alloc] initWithFrame:NSZeroRect];
  [subview setActivityView:view];
  return [subview autorelease];
}

- (void)activityDidChange
{
}

- (void)activityDidChangeField:(NSString *)name
{
}

- (void)activityDidChangeBody
{
}

- (void)selectedLapDidChange
{
}

- (NSEdgeInsets)edgeInsets
{
  return NSEdgeInsetsMake(0, 0, 0, 0);
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
  return [self bounds].size.height;
}

- (void)layoutSubviews
{
}

@end
