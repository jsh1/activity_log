// -*- c-style: gnu -*-

#import "ActActivityHeaderView.h"

#import "ActActivityViewController.h"
#import "ActActivityHeaderFieldView.h"

#import "ActFoundationExtensions.h"

#define FIELD_HEIGHT 12
#define FIELD_Y_SPACING 2
#define FOCUS_INSET 2

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
    {
      NSString *name = [subview fieldName];
      if ([name length] != 0)
	[array addObject:name];
    }

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
	  [new_subview setHeaderView:self];
	  [new_subview setController:[self controller]];
	  [new_subview setFieldName:field];
	}

      [new_subviews addObject:new_subview];
    }

  [self setSubviews:new_subviews];

  [new_subviews release];
  [old_subviews release];
}

- (ActActivityHeaderFieldView *)_ensureField:(NSString *)name
{
  for (ActActivityHeaderFieldView *subview in [self subviews])
    {
      if ([[subview fieldName] isEqualToStringNoCase:name])
	return subview;
    }

  ActActivityHeaderFieldView *field
    = [[ActActivityHeaderFieldView alloc] initWithFrame:NSZeroRect];

  [field setHeaderView:self];
  [field setController:[self controller]];
  [field setFieldName:name];

  [self addSubview:field];
  [field release];

  return field;
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
  [self _ensureField:name];
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

- (IBAction)controlAction:(id)sender
{
  if (sender == _addFieldButton)
    {
      ActActivityHeaderFieldView *field = [self _ensureField:@""];
      [self layoutAndResize];
      [[self window] makeFirstResponder:[field nameView]];
      [self scrollRectToVisible:[field convertRect:[field bounds] toView:self]];
    }
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

  return h + FOCUS_INSET * 2;
}

- (void)layoutSubviews
{
  NSRect bounds = [self bounds];
  NSRect frame = NSInsetRect(bounds, FOCUS_INSET, FOCUS_INSET);

  for (ActActivityHeaderFieldView *field in [self subviews])
    {
      frame.size.height = [field preferredHeight];
      [field setFrame:frame];
      [field layoutSubviews];
      frame.origin.y += frame.size.height + FIELD_Y_SPACING;
    }
}

- (void)layoutAndResize
{
  NSRect frame = [self frame];
  CGFloat height = [self preferredHeight];

  if (frame.size.height != height)
    {
      frame.size.height = height;
      [self setFrame:frame];
    }

  [self layoutSubviews];
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
