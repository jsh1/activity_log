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

#import "ActActivityTableViewCell.h"
#import "ActDatabaseManager.h"

@implementation ActActivitiesViewController

+ (ActActivitiesViewController *)instantiate
{
  return [[[NSBundle mainBundle] loadNibNamed:
	   @"ActivitiesView" owner:self options:nil] firstObject];
}

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

- (const act::database::query &)query
{
  return _query;
}

- (void)setQuery:(const act::database::query &)q
{
  _query = q;

  [self reloadData];
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

      [self reloadData];
    }
}

- (void)reloadData
{
  ActDatabaseManager *db = [ActDatabaseManager sharedManager];

  std::vector<act::database::item *> items;
  [db database]->execute_query(_query, items);

  if (_items != items)
    {
      using std::swap;
      swap(_items, items);

      /* FIXME: pull activities into our cache. */

      [[self tableView] reloadData];
    }
}

- (void)loadMoreData
{
  /* FIXME: something. */
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
  return !_moreItems ? 1 : 2;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec
{
  if (sec == 0)
    return _items.size();
  else
    return _moreItems ? 1 : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tv
    cellForRowAtIndexPath:(NSIndexPath *)path
{
  NSString *ident;
  UITableViewCell *cell;

  switch (path.section)
    {
    case 0:
      if (_viewMode == ActActivitiesViewList)
	ident = @"activityCell";
      else
	ident = @"weekCell";
      break;

    case 1:
      ident = @"moreCell";
      break;
    }

  cell = [tv dequeueReusableCellWithIdentifier:ident];

  if (cell == nil)
    {
      if ([ident isEqualToString:@"activityCell"])
	{
	  cell = [[ActActivityTableViewCell alloc]
		  initWithActivityStorage:_items[path.row]->storage()
		  reuseIdentifier:ident];
	}
      else if ([ident isEqualToString:@"weekCell"])
	{
	  /* FIXME: implement this. */

	  cell = [[UITableViewCell alloc] initWithStyle:
		  UITableViewCellStyleDefault reuseIdentifier:ident];
	  [[cell textLabel] setText:@"Week Cell"];
	}
      else if ([ident isEqualToString:@"moreCell"])
	{
	  cell = [[UITableViewCell alloc] initWithStyle:
		  UITableViewCellStyleDefault reuseIdentifier:ident];
	  [[cell textLabel] setText:@"More Data"];
	}
    }

  return cell;
}

- (void)tableView:(UITableView *)tv willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)path
{
  if ([[cell reuseIdentifier] isEqualToString:@"moreCell"])
    {
      [self loadMoreData];
    }
}

@end
