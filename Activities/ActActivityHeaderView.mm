// -*- c-style: gnu -*-

#import "ActActivityHeaderView.h"

#import "ActActivityView.h"
#import "ActActivityHeaderFieldView.h"

#import "ActFoundationExtensions.h"

#define FIELD_HEIGHT 12
#define FIELD_TOP_BORDER 4
#define FIELD_BOTTOM_BORDER 4
#define FIELD_Y_SPACING 3

@implementation ActActivityHeaderView

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self == nil)
    return nil;

  return self;
}

- (NSArray *)displayedFields
{
  NSMutableArray *array = [[NSMutableArray alloc] init];

  for (ActActivityHeaderFieldView *subview in [self subviews])
    [array addObject:[subview fieldName]];

  return [array autorelease];
}

- (void)setDisplayedFields:(NSArray *)array
{
  NSMutableArray *old_subviews = [[self subviews] mutableCopy];
  NSMutableArray *new_subviews = [[NSMutableArray alloc] init];

  for (NSString *field in array)
    {
      ActActivityHeaderFieldView *new_subview = nil;

      NSInteger old_idx = 0;
      for (ActActivityHeaderFieldView *old_subview in old_subviews)
	{
	  if ([[old_subview fieldName] isEqualToStringNoCase:field])
	    {
	      new_subview = old_subview;
	      [old_subviews removeObjectAtIndex:old_idx];
	      break;
	    }
	  old_idx++;
	}

      if (new_subview == nil)
	{
	  new_subview = [[[ActActivityHeaderFieldView alloc]
			  initWithFrame:NSZeroRect] autorelease];

	  [new_subview setFieldName:field];
	  if (ActActivityView *view = [self activityView])
	    [new_subview setActivityView:view];
	}

      [new_subviews addObject:new_subview];
    }

  [self setSubviews:new_subviews];

  [new_subviews release];
  [old_subviews release];
}

- (BOOL)displaysField:(NSString *)name
{
  for (ActActivityHeaderFieldView *subview in [self subviews])
    {
      if ([[subview fieldName] isEqualToStringNoCase:name])
	return YES;
    }

  return NO;
}

- (void)addDisplayedField:(NSString *)name
{
  if ([self displaysField:name])
    return;

  ActActivityHeaderFieldView *field
    = [[ActActivityHeaderFieldView alloc] initWithFrame:NSZeroRect];

  [field setFieldName:name];

  if (ActActivityView *view = [self activityView])
    [field setActivityView:view];

  [self addSubview:field];
  [field release];
}

- (void)removeDisplayedField:(NSString *)name
{
  for (ActActivityHeaderFieldView *subview in [self subviews])
    {
      if ([[subview fieldName] isEqualToStringNoCase:name])
	{
	  [subview removeFromSuperview];
	  return;
	}
    }
}

- (void)setActivityView:(ActActivityView *)view
{
  [super setActivityView:view];

  for (ActActivityHeaderFieldView *field in [self subviews])
    [field setActivityView:view];
}

- (void)activityDidChange
{
  for (ActActivityHeaderFieldView *field in [self subviews])
    [field activityDidChange];
}

- (void)activityDidChangeField:(NSString *)name
{
  for (ActActivityHeaderFieldView *field in [self subviews])
    [field activityDidChangeField:name];
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
  NSArray *fields = [self subviews];

  if ([fields count] == 0)
    return 0;

  CGFloat height = FIELD_TOP_BORDER;

  for (ActActivityHeaderFieldView *field in fields)
    {
      height += [field preferredHeightForWidth:width];
      height += FIELD_Y_SPACING;
    }

  height -= FIELD_Y_SPACING;
  height += FIELD_BOTTOM_BORDER;

  return height;
}

- (void)layoutSubviews
{
  NSRect bounds = [self bounds];
  NSRect frame = bounds;

  frame.origin.y += FIELD_TOP_BORDER;

  for (ActActivityHeaderFieldView *field in [self subviews])
    {
      frame.size.height = [field preferredHeightForWidth:frame.size.width];
      [field setFrame:frame];
      [field layoutSubviews];
      frame.origin.y += frame.size.height;
      frame.origin.y += FIELD_Y_SPACING;
    }
}

- (BOOL)isFlipped
{
  return YES;
}

@end
