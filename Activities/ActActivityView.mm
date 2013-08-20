// -*- c-style: gnu -*-

#import "ActActivityView.h"

#import "ActActivityBodyView.h"

@interface ActActivityView ()
- (void)updateSize;
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
			 [ActActivityBodyView class],
			 nil];
    }

  for (Class cls in subview_classes)
    {
      NSView *view = [[cls alloc] initWithFrame:NSZeroRect];
      [view setActivityView:self];
      [self addSubview:view];
      [view release];
    }
}

- (void)activityDidChange
{
  if ([[self subviews] count] == 0)
    [self createSubviews];

  for (NSView *view in [self subviews])
    {
      [view activityDidChange];
    }

  [self updateSize];
}

- (void)updateSize
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

  for (NSView *view in [self subviews])
    {
      height += [view preferredHeightForWidth:width];
    }

  return height;
}

- (void)layoutSubviews
{
  NSRect bounds = [self bounds];
  NSRect frame = bounds;

  for (NSView *view in [self subviews])
    {
      frame.size.height = [view preferredHeightForWidth:frame.size.width];
      [view setFrame:frame];
      [view layoutSubviews];
      frame.origin.y += frame.size.height;
    }
}

- (BOOL)isFlipped
{
  return YES;
}

@end

@implementation NSView (ActActivitySubview)

- (ActActivityView *)activityView
{
  return nil;
}

- (void)setActivityView:(ActActivityView *)view
{
}

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
