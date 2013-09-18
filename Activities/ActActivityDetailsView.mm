// -*- c-style: gnu -*-

#import "ActActivityDetailsView.h"

#import "ActActivityView.h"
#import "ActActivityHeaderView.h"
#import "ActActivitySummaryView.h"

#import "ActFoundationExtensions.h"

#define TOP_BORDER 4
#define BOTTOM_BORDER 0
#define LEFT_BORDER 4
#define RIGHT_BORDER 4

@implementation ActActivityDetailsView

- (void)createSubviews
{
  static NSArray *subview_classes;

  if (subview_classes == nil)
    {
      subview_classes = [[NSArray alloc] initWithObjects:
			 [ActActivitySummaryView class],
			 [ActActivityHeaderView class],
			 nil];
    }

  for (Class cls in subview_classes)
    {
      if (ActActivitySubview *subview
	  = [cls subviewForView:[self activityView]])
	{
	  [self addSubview:subview];
	}
    }

  [self setVertical:NO];
}

- (void)activityDidChange
{
  BOOL hasSubviews = [[self subviews] count] != 0;
  const act::activity *a = [[self activityView] activity];

  if (a != nullptr && !hasSubviews)
    [self createSubviews];
  else if (a == nullptr && hasSubviews)
    [self setSubviews:[NSArray array]];

  for (ActActivitySubview *subview in [self subviews])
    {
      if (![subview isKindOfClass:[ActActivityHeaderView class]])
	continue;

      ActActivityHeaderView *header = (id) subview;

      [header setDisplayedFields:[NSArray array]];

      if (a != nullptr)
	{
	  if (a->resting_hr() != 0)
	    [header addDisplayedField:@"Resting-HR"];
	  if (a->average_hr() != 0)
	    [header addDisplayedField:@"Average-HR"];
	  if (a->max_hr() != 0)
	    [header addDisplayedField:@"Max-HR"];

	  if (a->points() != 0)
	    [header addDisplayedField:@"Points"];
	  if (a->effort() != 0)
	    [header addDisplayedField:@"Effort"];
	  if (a->quality() != 0)
	    [header addDisplayedField:@"Quality"];

	  if (a->weight() != 0)
	    [header addDisplayedField:@"Weight"];
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

	  NSArray *ignoredFields = @[@"Date", @"Activity", @"Type", @"Course",
	    @"Distance", @"Duration", @"Pace", @"Speed", @"GPS-File"];

	  for (const auto &it : *a->storage())
	    {
	      NSString *str = [[NSString alloc]
			       initWithUTF8String:it.first.c_str()];
	      if (![header displaysField:str]
		  && ![ignoredFields containsStringNoCase:str])
		[header addDisplayedField:str];
	      [str release];
	    }
	}
    }

  [super activityDidChange];
}

- (NSEdgeInsets)edgeInsets
{
  return NSEdgeInsetsMake(TOP_BORDER, LEFT_BORDER,
			  BOTTOM_BORDER, RIGHT_BORDER);
}

@end
