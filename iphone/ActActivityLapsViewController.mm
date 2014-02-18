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

#import "ActActivityLapsViewController.h"

#import "ActActivityLapCell.h"

@implementation ActActivityLapsViewController

- (id)init
{
  return [super initWithNibName:@"ActivityLapsView" bundle:nil];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (ActActivityViewController *)controller
{
  return (ActActivityViewController *)self.parentViewController;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [(UITableView *)self.view registerNib:
   [UINib nibWithNibName:[ActActivityLapCell nibName] bundle:nil]
   forCellReuseIdentifier:@"lapCell"];
}

- (NSArray *)rightBarButtonItems
{
  return @[];
}

- (void)reloadData
{
  [(UITableView *)self.view reloadData];
}

- (void)willAnimateRotationToInterfaceOrientation:
    (UIInterfaceOrientation)orientation duration:(NSTimeInterval)dur
{
  [(UITableView *)self.view reloadData];
}

/* UITableViewDataSource methods. */

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec
{
  const act::activity *activity = self.controller.activity;
  if (activity == nullptr)
    return 0;

  const act::gps::activity *gps_data = activity->gps_data();
  if (gps_data == nullptr)
    return 0;

  return gps_data->laps().size();
}

- (UITableViewCell *)tableView:(UITableView *)tv
    cellForRowAtIndexPath:(NSIndexPath *)path
{
  ActActivityLapCell *cell = [tv dequeueReusableCellWithIdentifier:@"lapCell"];

  cell.activity = self.controller.activity;
  cell.lapIndex = path.row;

  [cell reloadData];

  return cell;
}

@end
