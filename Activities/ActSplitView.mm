// -*- c-style: gnu -*-

#import "ActSplitView.h"

@implementation ActSplitView

- (NSDictionary *)savedViewState
{
  NSArray *subviews = [self subviews];
  NSRect bounds = [self bounds];
  BOOL vertical = [self isVertical];
  CGFloat size = vertical ? bounds.size.width : bounds.size.height;

  NSMutableArray *data = [NSMutableArray array];

  for (NSView *subview in subviews)
    {
      NSRect frame = [subview frame];
      CGFloat x = vertical ? frame.origin.x : frame.origin.y;
      CGFloat w = vertical ? frame.size.width : frame.size.height;
      [data addObject:[NSNumber numberWithDouble:x / size]];
      [data addObject:[NSNumber numberWithDouble:w / size]];
      [data addObject:[NSNumber numberWithBool:[subview isHidden]]];
    }

   return @{@"values": data};
}

- (void)applySavedViewState:(NSDictionary *)dict
{
  NSArray *data = [dict objectForKey:@"values"];

  NSArray *subviews = [self subviews];
  NSInteger count = [subviews count];

  if ([data count] != count * 3)
    return;

  NSRect bounds = [self bounds];
  BOOL vertical = [self isVertical];
  CGFloat size = vertical ? bounds.size.width : bounds.size.height;

  for (NSInteger i = 0; i < count; i++)
    {
      CGFloat x = [[data objectAtIndex:i*3+0] doubleValue] * size;
      CGFloat w = [[data objectAtIndex:i*3+1] doubleValue] * size;
      BOOL flag = [[data objectAtIndex:i*3+2] boolValue];

      NSView *subview = [subviews objectAtIndex:i];
      NSRect frame = bounds;

      if (vertical)
	{
	  frame.origin.x = x;
	  frame.size.width = w;
	}
      else
	{
	  frame.origin.y = x;
	  frame.size.height = w;
	}

      [subview setHidden:flag];
      [subview setFrame:frame];
    }

  [self adjustSubviews];
}

- (void)setSubview:(NSView *)subview collapsed:(BOOL)flag
{
  if (flag != [subview isHidden])
    {
      [subview setHidden:flag];

      _collapsingSubview = subview;
      [self adjustSubviews];
      _collapsingSubview = nil;
    }
}

- (BOOL)shouldAdjustSizeOfSubview:(NSView *)subview
{
  if (_collapsingSubview != nil)
    {
      if (subview == _collapsingSubview)
	return NO;

      // If more than two subviews, only move those adjacent to the
      // [un]collapsing view.

      NSArray *subviews = [self subviews];
      NSInteger idx1 = [subviews indexOfObjectIdenticalTo:_collapsingSubview];
      NSInteger idx2 = [subviews indexOfObjectIdenticalTo:subview];

      if (abs(idx1 - idx2) > 1)
	return NO;
    }

  return YES;
}

- (CGFloat)minimumSizeOfSubview:(NSView *)subview
{
  if ([subview respondsToSelector:@selector(minSize)])
    return [subview minSize];
  else
    return 100;
}

@end
