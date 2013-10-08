// -*- c-style: gnu -*-

#import "ActHeaderViewController.h"

#import "ActHeaderView.h"
#import "ActHorizontalBoxView.h"
#import "ActWindowController.h"

#import "act-database.h"

#import "ActFoundationExtensions.h"

#define CORNER_RADIUS 6

@implementation ActHeaderViewController

+ (NSString *)viewNibName
{
  return @"ActHeaderView";
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:_controller];

  [_headerView viewDidLoad];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [super dealloc];
}

- (void)_updateHeaderFields
{
  const act::activity *a = [_controller selectedActivity];

  [_headerView setDisplayedFields:[NSArray array]];

  if (a != nullptr)
    {
      if (a->average_hr() != 0)
	[_headerView addDisplayedField:@"Average-HR"];
      if (a->max_hr() != 0)
	[_headerView addDisplayedField:@"Max-HR"];

      if (a->vdot() != 0)
	[_headerView addDisplayedField:@"VDOT"];
      if (a->points() != 0)
	[_headerView addDisplayedField:@"Points"];

      if (a->effort() != 0)
	[_headerView addDisplayedField:@"Effort"];
      if (a->quality() != 0)
	[_headerView addDisplayedField:@"Quality"];

      if (a->calories() != 0)
	[_headerView addDisplayedField:@"Calories"];
      if (a->weight() != 0)
	[_headerView addDisplayedField:@"Weight"];
      if (a->resting_hr() != 0)
	[_headerView addDisplayedField:@"Resting-HR"];

      if (a->temperature() != 0)
	[_headerView addDisplayedField:@"Temperature"];
      if (a->dew_point() != 0)
	[_headerView addDisplayedField:@"Dew-Point"];
      if (a->field_ptr("weather") != nullptr)
	[_headerView addDisplayedField:@"Weather"];

      if (a->field_ptr("equipment") != nullptr)
	[_headerView addDisplayedField:@"Equipment"];

      NSArray *ignoredFields = @[@"Date", @"Activity", @"Type", @"Course",
	@"Distance", @"Duration", @"Pace", @"Speed", @"GPS-File"];

      for (const auto &it : *a->storage())
	{
	  NSString *str = [[NSString alloc]
			   initWithUTF8String:it.first.c_str()];
	  if (![_headerView displaysField:str]
	      && ![ignoredFields containsStringNoCase:str])
	    [_headerView addDisplayedField:str];
	  [str release];
	}
    }

  [_headerView layoutAndResize];
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  [self _updateHeaderFields];
}

@end
