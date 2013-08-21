// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

#import "ActActivityView.h"

@implementation ActActivitySubview

@synthesize activityView = _activityView;

- (void)activityDidChange
{
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
  return [self bounds].size.height;
}

- (void)layoutSubviews
{
}

@end
