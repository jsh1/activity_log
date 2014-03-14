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

#import "ActActivityChartListViewController.h"

#import "ActActivityChartItemView.h"

#define PORTRAIT_ROW_HEIGHT 128
#define LANDSCAPE_ROW_HEIGHT 212

static NSString *
chart_title(int type)
{
  switch (type)
    {
    case ActActivityChartSpeed:
      return @"Pace";
    case ActActivityChartHeartRate:
      return @"Heart Rate";
    case ActActivityChartCadence:
      return @"Cadence";
    case ActActivityChartAltitude:
      return @"Altitude";
    case ActActivityChartVerticalOscillation:
      return @"Vertical Oscillation";
    case ActActivityChartStanceTime:
      return @"Stance Time";
    case ActActivityChartStrideLength:
      return @"Stride Length";
    default:
      return nil;
    }
}

@implementation ActActivityChartListViewController

- (id)init
{
  return [super initWithNibName:@"ActivityChartListView" bundle:nil];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (ActActivityViewController *)controller
{
  return (ActActivityViewController *)self.parentViewController;
}

- (void)updateRowHeight
{
  UIInterfaceOrientation orient = self.interfaceOrientation;
  CGFloat rh = (orient == UIInterfaceOrientationPortrait
		|| orient == UIInterfaceOrientationPortraitUpsideDown
		? PORTRAIT_ROW_HEIGHT : LANDSCAPE_ROW_HEIGHT);
  ((UITableView *)self.view).rowHeight = rh;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  _smoothingControl = [[UISegmentedControl alloc]
		       initWithItems:@[@"0s", @"15s", @"1m", @"4m"]];
  [_smoothingControl addTarget:self action:@selector(smoothingAction:)
   forControlEvents:UIControlEventValueChanged];

  _smoothingItem = [[UIBarButtonItem alloc]
		    initWithCustomView:_smoothingControl];

  _smoothing = (int) [[NSUserDefaults standardUserDefaults]
		integerForKey:@"ActActivityChartListView.smoothing"];

  NSInteger idx = -1;
  if (_smoothing == 0)
    idx = 0;
  else if (_smoothing == 15)
    idx = 1;
  else if (_smoothing == 60)
    idx = 2;
  else if (_smoothing == 60*4)
    idx = 3;

  if (idx >= 0)
    _smoothingControl.selectedSegmentIndex = idx;

  _pressRecognizer = [[UILongPressGestureRecognizer alloc]
		      initWithTarget:self action:@selector(pressAction:)];
  _pressRecognizer.minimumPressDuration = .25;
  [self.view addGestureRecognizer:_pressRecognizer];

  [self updateRowHeight];
}

- (NSArray *)rightBarButtonItems
{
  return @[_smoothingItem];
}

- (const act::gps::activity *)smoothedData
{
  const act::activity *a = self.controller.activity;
  if (a == nullptr)
    return nullptr;

  const act::gps::activity *gps_a = a->gps_data();
  if (gps_a == nullptr)
    return nullptr;

  if (!_smoothedData
      || _dataSmoothing != _smoothing
      || _smoothedData->start_time() != gps_a->start_time()
      || _smoothedData->total_distance() != gps_a->total_distance()
      || _smoothedData->total_duration() != gps_a->total_duration())
    {
      if (_smoothing > 0)
	{
	  _smoothedData.reset(new act::gps::activity);
	  _smoothedData->smooth(*gps_a, _smoothing);
	}
      else if (_smoothedData)
	_smoothedData.reset();

      _dataSmoothing = _smoothing;
    }

  if (_smoothedData != nullptr)
    return _smoothedData.get();
  else
    return gps_a;
}

- (void)reloadData
{
  NSMutableArray *array = [[NSMutableArray alloc] init];

  if (const act::activity *activity = self.controller.activity)
    {
      if (const act::gps::activity *gps_data = activity->gps_data())
	{
	  if (gps_data->has_speed())
	    [array addObject:@(ActActivityChartSpeed)];
	  if (gps_data->has_heart_rate())
	    [array addObject:@(ActActivityChartHeartRate)];
	  if (gps_data->has_altitude())
	    [array addObject:@(ActActivityChartAltitude)];
	  if (gps_data->has_cadence())
	    [array addObject:@(ActActivityChartCadence)];
	  if (gps_data->has_dynamics())
	    {
	      [array addObject:@(ActActivityChartVerticalOscillation)];
	      [array addObject:@(ActActivityChartStanceTime)];
	      if (gps_data->has_cadence())
		[array addObject:@(ActActivityChartStrideLength)];
	    }
	}
    }

  _chartTypes = array;

  [(UITableView *)self.view reloadData];
}

- (void)smoothingAction:(id)sender
{
  NSInteger idx = _smoothingControl.selectedSegmentIndex;

  if (idx == 0)
    _smoothing = 0;
  else if (idx == 1)
    _smoothing = 15;
  else if (idx == 2)
    _smoothing = 60;
  else if (idx == 3)
    _smoothing = 60*4;

  [[NSUserDefaults standardUserDefaults]
   setInteger:_smoothing forKey:@"ActActivityChartListView.smoothing"];

  [self reloadData];
}

- (void)pressAction:(id)sender
{
  if (_pressRecognizer.state == UIGestureRecognizerStateBegan)
    {
      self.controller.fullscreen = !self.controller.fullscreen;
      [self.view setNeedsLayout];
    }
}

- (void)willAnimateRotationToInterfaceOrientation:
    (UIInterfaceOrientation)orientation duration:(NSTimeInterval)dur
{
  [self updateRowHeight];
  [(UITableView *)self.view reloadData];
}

/* UITableViewDataSource methods. */

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
  return [_chartTypes count];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec
{
  return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tv
    cellForRowAtIndexPath:(NSIndexPath *)path
{
  NSString *ident = @"chartCell";

  UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];

  if (cell == nil)
    {
      if ([ident isEqualToString:@"chartCell"])
	{
	  cell = [[UITableViewCell alloc] initWithStyle:
		  UITableViewCellStyleDefault reuseIdentifier:ident];

	  ActActivityChartItemView *view
	    = [[ActActivityChartItemView alloc] init];

	  view.controller = self;
	  view.frame = cell.contentView.bounds;
	  view.autoresizingMask = (UIViewAutoresizingFlexibleWidth
				   | UIViewAutoresizingFlexibleHeight);

	  /* The paths are complex, use the accelerated CG renderer. */

	  view.layer.drawsAsynchronously = YES;

	  [cell.contentView addSubview:view];
	}
    }

  if ([ident isEqualToString:@"chartCell"])
    {
      ActActivityChartItemView *view
        = (id)[cell.contentView.subviews firstObject];

      view.activity = self.controller.activity;
      view.chartType = [_chartTypes[path.section] intValue];
      [view reloadData];
    }

  return cell;
}

/* UITableViewDelegate methods. */

- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)sec
{
  NSString *ident = @"chartHeader";

  UITableViewHeaderFooterView *view
    = [tv dequeueReusableHeaderFooterViewWithIdentifier:ident];

  if (view == nil)
    {
      view = [[UITableViewHeaderFooterView alloc]
	      initWithReuseIdentifier:ident];
    }

  view.textLabel.text = chart_title([_chartTypes[sec] intValue]);

  return view;
}

@end
