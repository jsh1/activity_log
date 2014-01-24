/* -*- c-style: gnu -*-

   Copyright (c) 2013 John Harper <jsh@unfactored.org>

   Permission is hereby granted, free of charge, to any person
   obtaining a copy of this software and associated documentation files
   (the "Software"), to deal in the Software without restriction,
   including without limitation the rights to use, copy, modify, merge,
   publish, distribute, sublicense, and/or sell copies of the Software,
   and to permit persons to whom the Software is furnished to do so,
   subject to the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE. */

#import "ActHeaderViewController.h"

#import "ActCollapsibleView.h"
#import "ActHeaderView.h"
#import "ActHorizontalBoxView.h"
#import "ActViewLayout.h"
#import "ActWindowController.h"

#import "act-database.h"

#import "FoundationExtensions.h"

#define CORNER_RADIUS 6

@implementation ActHeaderViewController

+ (NSString *)viewNibName
{
  return @"ActHeaderView";
}

- (id)initWithController:(ActWindowController *)controller
    options:(NSDictionary *)opts
{
  self = [super initWithController:controller options:opts];
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
      if (a->elapsed_time() != 0)
	[_headerView addDisplayedField:@"Elapsed-Time"];

      if (a->avg_hr() != 0)
	[_headerView addDisplayedField:@"Avg-HR"];
      if (a->max_hr() != 0)
	[_headerView addDisplayedField:@"Max-HR"];

      if (a->avg_cadence() != 0)
	[_headerView addDisplayedField:@"Avg-Cadence"];
      if (a->max_cadence() != 0)
	[_headerView addDisplayedField:@"Max-Cadence"];

      if (a->vdot() != 0)
	[_headerView addDisplayedField:@"VDOT"];
      if (a->efficiency() != 0)
	[_headerView addDisplayedField:@"Efficiency"];
      if (a->points() != 0)
	[_headerView addDisplayedField:@"Points"];

      if (a->avg_vertical_oscillation() != 0)
	[_headerView addDisplayedField:@"Avg-Vertical-Oscillation"];
      if (a->avg_stance_time() != 0)
	[_headerView addDisplayedField:@"Avg-Stance-Time"];
      if (a->avg_stance_ratio() != 0)
	[_headerView addDisplayedField:@"Avg-Stance-Ratio"];
      if (a->avg_stride_length() != 0)
	[_headerView addDisplayedField:@"Avg-Stride-Length"];

      if (a->training_effect() != 0)
	[_headerView addDisplayedField:@"Training-Effect"];
      if (a->calories() != 0)
	[_headerView addDisplayedField:@"Calories"];
      if (a->weight() != 0)
	[_headerView addDisplayedField:@"Weight"];
      if (a->resting_hr() != 0)
	[_headerView addDisplayedField:@"Resting-HR"];

      if (a->ascent() != 0)
	[_headerView addDisplayedField:@"Ascent"];
      if (a->descent() != 0)
	[_headerView addDisplayedField:@"Descent"];

      if (a->effort() != 0)
	[_headerView addDisplayedField:@"Effort"];
      if (a->quality() != 0)
	[_headerView addDisplayedField:@"Quality"];

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
	      && ![ignoredFields containsString:str caseInsensitive:YES])
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
