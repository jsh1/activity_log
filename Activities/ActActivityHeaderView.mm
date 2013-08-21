// -*- c-style: gnu -*-

#import "ActActivityHeaderView.h"

#import "ActActivityView.h"
#import "ActActivityHeaderFieldView.h"

#define FIELD_HEIGHT 12
#define FIELD_TOP_BORDER 4
#define FIELD_BOTTOM_BORDER 8
#define FIELD_Y_SPACING 4

@implementation ActActivityHeaderView

static NSArray *_displayedFields;

+ (void)initialize
{
  if (self == [ActActivityHeaderView class])
    {
      _displayedFields = [[NSArray alloc] initWithObjects:@"Date",
			  @"Activity", @"Type", @"Course", @"Distance",
			  @"Duration", @"Pace", @"Equipment", nil];
    }
}

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self == nil)
    return nil;

  for (NSString *name in _displayedFields)
    [self addFieldView:name];

  return self;
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
