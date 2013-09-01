// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

#import "ActActivityView.h"

@implementation ActActivitySubview

@synthesize activityView = _activityView;

- (void)activityDidChange
{
}

- (void)activityDidChangeField:(NSString *)name
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
