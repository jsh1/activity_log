// -*- c-style: gnu -*-

#import "ActActivityView.h"

#import "ActActivityBodyView.h"
#import "ActActivityChartView.h"
#import "ActActivityHeaderView.h"
#import "ActActivityLapView.h"
#import "ActActivitySubView.h"
#import "ActWindowController.h"

#import "ActFoundationExtensions.h"

#define SUBVIEW_Y_SPACING 14

#undef FONT_NAME

@implementation ActActivityView

static NSArray *_ignoredFields;

+ (void)initialize
{
  if (self == [ActActivityView class])
    {
      _ignoredFields = [[NSArray alloc] initWithObjects:@"GPS-File", nil];
    }
}

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

- (NSInteger)selectedLapIndex
{
  return _selectedLapIndex;
}

- (void)setSelectedLapIndex:(NSInteger)idx
{
  if (_selectedLapIndex != idx)
    {
      _selectedLapIndex = idx;

      [self selectedLapDidChange];
    }
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

  _selectedLapIndex = -1;

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
  BOOL hasSubviews = [[self subviews] count] != 0;

  if (_activity_storage != nullptr && !hasSubviews)
    [self createSubviews];
  else if (_activity_storage == nullptr && hasSubviews)
    [self setSubviews:[NSArray array]];

  for (ActActivitySubview *subview in [self subviews])
    {
      if ([subview isKindOfClass:[ActActivityHeaderView class]])
	{
	  ActActivityHeaderView *header = (id) subview;

	  [header setDisplayedFields:
	   [NSArray arrayWithObjects:@"Date", @"Activity", @"Type",
	    @"Course", @"Distance", @"Duration", @"Pace", nil]];

	  if (const act::activity *a = [self activity])
	    {
	      if (a->resting_hr() != 0)
		[header addDisplayedField:@"Resting-HR"];
	      if (a->average_hr() != 0)
		[header addDisplayedField:@"Average-HR"];
	      if (a->max_hr() != 0)
		[header addDisplayedField:@"Max-HR"];
	      if (a->calories() != 0)
		[header addDisplayedField:@"Calories"];

	      if (a->temperature() != 0)
		[header addDisplayedField:@"Temperature"];
	      if (a->dew_point() != 0)
		[header addDisplayedField:@"Dew-Point"];
	      if (a->field_ptr("weather") != nullptr)
		[header addDisplayedField:@"Weather"];

	      if (a->field_ptr("equipment") != nullptr)
		[header addDisplayedField:@"Equipment"];

	      for (const auto &it : *_activity_storage)
		{
		  NSString *str = [[NSString alloc]
				   initWithUTF8String:it.first.c_str()];
		  if (![header displaysField:str]
		      && ![_ignoredFields containsStringNoCase:str])
		    [header addDisplayedField:str];
		  [str release];
		}
	    }
	}

      [subview activityDidChange];
    }

  [self updateHeight];
}

- (void)activityDidChangeField:(NSString *)name
{
  [_controller reloadSelectedActivity];

  for (ActActivitySubview *subview in [self subviews])
    [subview activityDidChangeField:name];
}

- (void)activityDidChangeBody
{
  for (ActActivitySubview *subview in [self subviews])
    [subview activityDidChangeBody];
}

- (void)selectedLapDidChange
{
  for (ActActivitySubview *subview in [self subviews])
    {
      [subview selectedLapDidChange];
    }
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
#ifdef FONT_NAME
      font = [NSFont fontWithName:@FONT_NAME size:fontSize];
#endif
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
