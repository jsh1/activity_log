// -*- c-style: gnu -*-

#import "ActActivityMiddleView.h"

#import "ActActivityView.h"
#import "ActActivityLapView.h"
#import "ActActivityMapView.h"

#define TOP_BORDER 0
#define BOTTOM_BORDER 0
#define LEFT_BORDER 4
#define RIGHT_BORDER 4

@implementation ActActivityMiddleView

- (void)createSubviews
{
  static NSArray *subview_classes;

  if (subview_classes == nil)
    {
      subview_classes = [[NSArray alloc] initWithObjects:
			 [ActActivityLapView class],
			 [ActActivityMapView class],
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

  [super activityDidChange];
}

- (NSEdgeInsets)edgeInsets
{
  return NSEdgeInsetsMake(TOP_BORDER, LEFT_BORDER,
			  BOTTOM_BORDER, RIGHT_BORDER);
}

@end
