// -*- c-style: gnu -*-

#import "ActActivityHeaderView.h"

#import "ActActivityViewController.h"
#import "ActActivityHeaderFieldView.h"

#import "ActFoundationExtensions.h"

#define FIELD_HEIGHT 12
#define FIELD_Y_SPACING 2

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

	  if (ActActivityViewController *controller = [self controller])
	    [new_subview setController:controller];

	  [new_subview setFieldName:field];
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

  if (ActActivityViewController *controller = [self controller])
    [field setController:controller];

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

- (void)setController:(ActActivityViewController *)controller
{
  [super setController:controller];

  for (ActActivityHeaderFieldView *field in [self subviews])
    [field setController:controller];
}

- (CGFloat)preferredHeight
{
  CGFloat h = 0;

  for (ActActivityHeaderFieldView *field in [self subviews])
    {
      if (h != 0)
	h += FIELD_Y_SPACING;
      h += [field preferredHeight];
    }

  return h;
}

- (void)layoutSubviews
{
  NSRect bounds = [self bounds];
  NSRect frame = bounds;

  for (ActActivityHeaderFieldView *field in [self subviews])
    {
      frame.size.height = [field preferredHeight];
      [field setFrame:frame];
      [field layoutSubviews];
      frame.origin.y += frame.size.height + FIELD_Y_SPACING;
    }
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
  [super resizeSubviewsWithOldSize:oldSize];
  [self layoutSubviews];
}

- (BOOL)isFlipped
{
  return YES;
}

@end
