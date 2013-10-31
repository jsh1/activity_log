// -*- c-style: gnu -*-

#import "ActHeaderViewController.h"

#import "ActCollapsibleView.h"
#import "ActHeaderView.h"
#import "ActHorizontalBoxView.h"
#import "ActViewLayout.h"
#import "ActWindowController.h"

#import "act-database.h"

#import "ActFoundationExtensions.h"

#define CORNER_RADIUS 6

@implementation ActHeaderViewController

+ (NSString *)viewNibName
{
  return @"ActHeaderView";
}

- (id)initWithController:(ActWindowController *)controller
{
  self = [super initWithController:controller];
  if (self == nil)
    return nil;

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:_controller];

  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [_headerView viewDidLoad];

  [(ActCollapsibleView *)[self view] setTitle:@"Data Fields"];

  // creating layers for each subview is not gaining us anything
  [[self view] setCanDrawSubviewsIntoLayer:YES];

  [_boxView setRightToLeft:YES];
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
      if (a->vdot() != 0)
	[_headerView addDisplayedField:@"VDOT"];
      if (a->points() != 0)
	[_headerView addDisplayedField:@"Points"];

      if (a->average_hr() != 0)
	[_headerView addDisplayedField:@"Average-HR"];
      if (a->max_hr() != 0)
	[_headerView addDisplayedField:@"Max-HR"];

      if (a->elapsed_time() != 0)
	[_headerView addDisplayedField:@"Elapsed-Time"];

      if (a->ascent() != 0)
	[_headerView addDisplayedField:@"Ascent"];
      if (a->descent() != 0)
	[_headerView addDisplayedField:@"Descent"];

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

  [_containerView subviewNeedsLayout:_headerView];
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  [self _updateHeaderFields];
}

@end
