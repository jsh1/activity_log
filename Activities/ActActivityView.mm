// -*- c-style: gnu -*-

#import "ActActivityView.h"

#import "ActActivityBodyView.h"
#import "ActActivityChartView.h"
#import "ActActivityHeaderView.h"
#import "ActActivitySubView.h"

@interface ActActivityView ()
- (void)updateHeight;
@end

@implementation ActActivityView

- (act::activity_storage_ref)activityStorage
{
  return _activity_storage;
}

- (void)setActivityStorage:(act::activity_storage_ref)storage
{
  if (_activity_storage != storage)
    {
      _activity_storage = storage;
      _activity.reset();

      [self activityDidChange];
    }
}

- (act::activity *)activity
{
  if (!_activity && _activity_storage)
    _activity.reset(new act::activity(_activity_storage));

  return _activity.get();
}

- (void)createSubviews
{
  static NSArray *subview_classes;

  if (subview_classes == nil)
    {
      subview_classes = [[NSArray alloc] initWithObjects:
			 [ActActivityHeaderView class],
			 [ActActivityBodyView class],
			 [ActActivityPaceChartView class],
			 [ActActivityHeartRateChartView class],
			 [ActActivityAltitudeChartView class],
			 nil];
    }

  for (Class cls in subview_classes)
    {
      ActActivitySubview *view = [[cls alloc] initWithFrame:NSZeroRect];
      [view setActivityView:self];
      [self addSubview:view];
      [view release];
    }
}

- (void)activityDidChange
{
  if ([[self subviews] count] == 0)
    [self createSubviews];

  for (ActActivitySubview *subview in [self subviews])
    {
      [subview activityDidChange];
    }

  [self updateHeight];
}

- (void)updateHeight
{
  NSRect rect = [self frame];
  CGFloat height = [self preferredHeightForWidth:rect.size.width];

  if (rect.size.height != height)
    {
      rect.size.height = height;
      [self setFrame:rect];
    }

  [self layoutSubviews];
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
  CGFloat height = 0;

  for (ActActivitySubview *subview in [self subviews])
    {
      height += [subview preferredHeightForWidth:width];
    }

  return height;
}

- (void)layoutSubviews
{
  NSRect bounds = [self bounds];
  NSRect frame = bounds;

  for (ActActivitySubview *subview in [self subviews])
    {
      frame.size.height = [subview preferredHeightForWidth:frame.size.width];
      [subview setFrame:frame];
      [subview layoutSubviews];
      frame.origin.y += frame.size.height;
    }
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
  [super resizeSubviewsWithOldSize:oldSize];

  NSSize newSize = [self bounds].size;

  if (newSize.width != oldSize.width)
    [self updateHeight];
}

- (BOOL)isFlipped
{
  return YES;
}

@end
