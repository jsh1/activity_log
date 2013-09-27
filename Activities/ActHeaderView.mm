// -*- c-style: gnu -*-

#import "ActHeaderView.h"

#import "ActHeaderFieldView.h"
#import "ActWindowController.h"

#import "ActFoundationExtensions.h"

#define FIELD_HEIGHT 12
#define FIELD_Y_SPACING 2
#define FOCUS_INSET 2

@implementation ActHeaderView

- (ActWindowController *)controller
{
  return (ActWindowController *)[[self window] windowController];
}

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self == nil)
    return nil;

  return self;
}

- (void)viewDidLoad
{
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:[self controller]];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeField:)
   name:ActActivityDidChangeField object:[self controller]];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (NSArray *)displayedFields
{
  NSMutableArray *array = [[NSMutableArray alloc] init];

  for (ActHeaderFieldView *subview in [self subviews])
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
      ActHeaderFieldView *new_subview = nil;

      NSInteger old_idx = 0;
      for (ActHeaderFieldView *old_subview in old_subviews)
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
	  new_subview = [[[ActHeaderFieldView alloc]
			  initWithFrame:NSZeroRect] autorelease];
	  [new_subview setHeaderView:self];
	  [new_subview setFieldName:field];
	}

      [new_subviews addObject:new_subview];
    }

  [self setSubviews:new_subviews];

  [new_subviews release];
  [old_subviews release];
}

- (ActHeaderFieldView *)_ensureField:(NSString *)name
{
  for (ActHeaderFieldView *subview in [self subviews])
    {
      if ([[subview fieldName] isEqualToStringNoCase:name])
	return subview;
    }

  ActHeaderFieldView *field
    = [[ActHeaderFieldView alloc] initWithFrame:NSZeroRect];

  [field setHeaderView:self];
  [field setFieldName:name];

  [self addSubview:field];
  [field release];

  return field;
}

- (BOOL)displaysField:(NSString *)name
{
  for (ActHeaderFieldView *subview in [self subviews])
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
  for (ActHeaderFieldView *subview in [self subviews])
    {
      if ([[subview fieldName] isEqualToStringNoCase:name])
	{
	  [subview removeFromSuperview];
	  return;
	}
    }
}

- (IBAction)controlAction:(id)sender
{
  if (sender == _addFieldButton)
    {
      ActHeaderFieldView *field = [self _ensureField:@""];
      [self layoutAndResize];
      [[self window] makeFirstResponder:[field nameView]];
      [self scrollRectToVisible:[field convertRect:[field bounds] toView:self]];
    }
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  for (ActHeaderFieldView *subview in [self subviews])
    [subview update];
}

- (void)activityDidChangeField:(NSNotification *)note
{
  NSDictionary *dict = [note userInfo];

  void *ptr = [[dict objectForKey:@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);
  
  if (a == [[self controller] selectedActivityStorage])
    {
      for (ActHeaderFieldView *subview in [self subviews])
	[subview update];
    }
}

- (CGFloat)preferredHeight
{
  CGFloat h = 0;

  for (ActHeaderFieldView *field in [self subviews])
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

  for (ActHeaderFieldView *field in [self subviews])
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
