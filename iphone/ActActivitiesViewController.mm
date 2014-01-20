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

#import "ActActivitiesViewController.h"

@implementation ActActivitiesViewController

- (NSString *)title
{
  return @"Activities";
}

- (void)viewDidLoad
{
  _addItem = [[UIBarButtonItem alloc]
	initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
	target:self action:@selector(addActivityAction:)];

  _weekItem = [[UIBarButtonItem alloc]
	initWithTitle:@"Week" style:UIBarButtonItemStylePlain
	target:self action:@selector(toggleWeekAction:)];

  [[self navigationItem] setRightBarButtonItems:@[_addItem, _weekItem]];
}

- (NSInteger)viewMode
{
  return _viewMode;
}

- (void)setViewMode:(NSInteger)mode
{
  if (_viewMode != mode)
    {
      _viewMode = mode;
    }
}

- (IBAction)addActivityAction:(id)sender
{
}

- (IBAction)toggleWeekAction:(id)sender
{
}

/* UITableViewDataSource methods. */

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
  return 1;
}

- (NSString *)tableView:(UITableView *)tv
    titleForHeaderInSection:(NSInteger)sec
{
  return @"Section Title";
}

- (NSString *)tableView:(UITableView *)tv
    titleForFooterInSection:(NSInteger)sec
{
  return nil;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec
{
  return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tv
    cellForRowAtIndexPath:(NSIndexPath *)path
{
  NSString *ident;
  UITableViewCell *cell;

  ident = _viewMode == ActActivitiesViewList ? @"listCell" : @"weekCell";

  cell = [tv dequeueReusableCellWithIdentifier:ident];

  if (cell == nil)
    {
      cell = [[UITableViewCell alloc] initWithStyle:
	      UITableViewCellStyleDefault reuseIdentifier:ident];
      [[cell textLabel] setText:@"Test Item"];
    }

  return cell;
}

@end
