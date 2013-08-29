// -*- c-style: gnu -*-

#import "ActActivityView.h"

#import "ActActivityBodyView.h"
#import "ActActivityChartView.h"
#import "ActActivityHeaderView.h"
#import "ActActivityLapView.h"
#import "ActActivitySubView.h"

#define SUBVIEW_Y_SPACING 14

#define FONT_NAME "Bitstream Vera Sans Roman"

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
			 [ActActivityLapView class],
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
  CGFloat y = 0;

  for (ActActivitySubview *subview in [self subviews])
    {
      NSEdgeInsets insets = [subview edgeInsets];

      CGFloat sub_width = width - (insets.left + insets.right);
      CGFloat sub_height = [subview preferredHeightForWidth:sub_width];

      if (sub_width > 0 && sub_height > 0)
	y = y + insets.top + sub_height + insets.bottom + SUBVIEW_Y_SPACING;
    }

  return y;
}

- (void)layoutSubviews
{
  NSRect bounds = [self bounds];
  CGFloat x = bounds.origin.x;
  CGFloat y = bounds.origin.y;
  CGFloat width = bounds.size.width;

  for (ActActivitySubview *subview in [self subviews])
    {
      NSEdgeInsets insets = [subview edgeInsets];

      CGFloat sub_width = width - (insets.left + insets.right);
      CGFloat sub_height = [subview preferredHeightForWidth:sub_width];

      if (sub_width > 0 && sub_height > 0)
	{
	  NSRect frame = NSMakeRect(x + insets.left, y + insets.top,
				    sub_width, sub_height);

	  [subview setHidden:NO];
	  [subview setFrame:frame];
	  [subview layoutSubviews];

	  y = y + insets.top + sub_height + insets.bottom + SUBVIEW_Y_SPACING;
	}
      else
	[subview setHidden:YES];
    }
}

- (NSFont *)font
{
  static NSFont *font;

  if (font == nil)
    {
      CGFloat fontSize = [NSFont smallSystemFontSize];
      font = [NSFont fontWithName:@FONT_NAME size:fontSize];
      if (font == nil)
	font = [NSFont systemFontOfSize:fontSize];
    }

  return font;
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
