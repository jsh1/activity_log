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

  _displayedFields = [[NSMutableArray alloc] init];

  return self;
}

- (void)dealloc
{
  [_displayedFields release];

  [super dealloc];
}

- (NSArray *)displayedFields
{
  return [[_displayedFields copy] autorelease];
}

- (void)setDisplayedFields:(NSArray *)array
{
  if (_displayedFields != array)
    {
      [_displayedFields removeAllObjects];

      if (array != nil)
	[_displayedFields addObjectsFromArray:array];

      [self setSubviews:[NSArray array]];

      if ([self activityView] != nil)
	[self activityDidChange];
    }
}

- (BOOL)displaysField:(NSString *)name
{
  return [_displayedFields indexOfStringNoCase:name] != NSNotFound;
}

- (void)addDisplayedField:(NSString *)name
{
  NSInteger idx = [_displayedFields indexOfStringNoCase:name];

  if (idx == NSNotFound)
    {
      [_displayedFields addObject:name];

      if ([self activityView] != nil)
	[self addFieldView:name];
    }
}

- (void)removeDisplayedField:(NSString *)name
{
  NSInteger idx = [_displayedFields indexOfStringNoCase:name];

  if (idx != NSNotFound)
    {
      [_displayedFields removeObjectAtIndex:idx];

      NSArray *subviews = [self subviews];
      if ([subviews count] >= idx)
	[[subviews objectAtIndex:idx] removeFromSuperview];
    }
}

- (void)addFieldView:(NSString *)name
{
  ActActivityHeaderFieldView *field
    = [[ActActivityHeaderFieldView alloc] initWithFrame:NSZeroRect];

  [field setActivityView:[self activityView]];
  [field setFieldName:name];
  [self addSubview:field];

  [field release];
}

- (void)setActivityView:(ActActivityView *)view
{
  [super setActivityView:view];

  for (ActActivityHeaderFieldView *field in [self subviews])
    [field setActivityView:view];
}

- (void)activityDidChange
{
  if ([[self subviews] count] == 0)
    {
      for (NSString *name in _displayedFields)
	[self addFieldView:name];
    }

  for (ActActivityHeaderFieldView *field in [self subviews])
    [field activityDidChange];
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
