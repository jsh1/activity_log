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

#import "ActActivityListItemView.h"
#import "ActActivityViewController.h"
#import "ActDatabaseManager.h"

#import "act-util.h"

#import <xlocale.h>

@interface ActActivityLoadMoreCell : UITableViewCell
{
  time_t _earliestTime;
}
@property(nonatomic) time_t earliestTime;
@end

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
  [super viewDidLoad];

  ActDatabaseManager *db = [ActDatabaseManager sharedManager];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(metadataCacheDidChange:)
   name:ActMetadataCacheDidChange object:db];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDatabaseDidChange:)
   name:ActActivityDatabaseDidChange object:db];

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
  _earliestTime = 0;

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

      [self.tableView reloadData];
      _needReloadView = NO;
    }
}

- (void)reloadData
{
  ActDatabaseManager *db = [ActDatabaseManager sharedManager];

  /* Pull activity files spanning the query's partial date range into
     the database. */

  _ignoreNotifications++;

  act::date_range range;
  for (const auto &it : _query.date_ranges())
    range.merge(it);

  if (!range.is_empty())
    {
      struct tm tm = {0};
      time_t last = range.start + range.length - 1;
      localtime_r(&last, &tm);

      int year = tm.tm_year + 1900;
      int month = tm.tm_mon;

      if (_earliestTime == 0)
	_earliestTime = act::month_time(year, month - 1);

      time_t min_time = std::max(_earliestTime, range.start);

      while (1)
	{
	  act::standardize_month(year, month);

	  time_t month_start = act::month_time(year, month);
	  time_t month_end = month_start + act::seconds_in_month(year, month);

	  if (!(month_end > min_time))
	    break;

	  char buf[64];
	  snprintf_l(buf, sizeof(buf), nullptr, "%d/%02d", year, month + 1);

	  NSString *dir = [NSString stringWithUTF8String:buf];

	  NSDictionary *dict = [db activityMetadataForPath:dir];

	  /* Sort files into reverse order, as that's how we display. */

	  NSArray *contents = dict[@"contents"];
	  contents = [contents sortedArrayUsingComparator:^
		      NSComparisonResult (id a, id b) {
			return [b[@"name"] compare:a[@"name"]];
		      }];

	  for (NSDictionary *sub_dict in contents)
	    {
	      if ([sub_dict[@"directory"] boolValue])
		continue;

	      NSString *name = sub_dict[@"name"];
	      NSString *path = [dir stringByAppendingPathComponent:name];
	      NSString *rev = sub_dict[@"rev"];

	      [db loadActivityFromPath:path revision:rev];
	    }

	  month--;
	}

      _moreItems = _earliestTime > range.start;
    }

  _ignoreNotifications--;

  /* Reload the query results and update the table view. */

  std::vector<act::database::item> items;
  db.database->execute_query(_query, items);

  if (_items != items)
    {
      using std::swap;
      swap(_items, items);
      _needReloadView = YES;
    }

  if (_needReloadView)
    {
      [self.tableView reloadData];
      _needReloadView = NO;
    }
}

- (void)loadMoreData:(time_t)earliest
{
  struct tm tm = {0};
  localtime_r(&earliest, &tm);

  earliest = act::month_time(tm.tm_year + 1900, tm.tm_mon - 1);

  if (earliest < _earliestTime)
    {
      _earliestTime = earliest;
      _needReloadView = YES;
      [self reloadData];
    }
}

- (act::activity_list_item_ref)listItemForIndex:(size_t)idx
{
  if (_listItems.size() != _items.size())
    _listItems.resize(_items.size());

  if (!_listItems[idx]
      || _listItems[idx]->activity->storage() != _items[idx].storage())
    _listItems[idx].reset(new act::activity_list_item(_items[idx].storage()));

  return _listItems[idx];
}

- (void)metadataCacheDidChange:(NSNotification *)note
{
  if (_ignoreNotifications == 0)
    [self reloadData];
}

- (void)activityDatabaseDidChange:(NSNotification *)note
{
  if (_ignoreNotifications == 0)
    [self reloadData];
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
      ident = @"loadMoreCell";
      break;
    }

  cell = [tv dequeueReusableCellWithIdentifier:ident];

  if (cell == nil)
    {
      if ([ident isEqualToString:@"activityCell"])
	{
	  cell = [[UITableViewCell alloc] initWithStyle:
		  UITableViewCellStyleDefault reuseIdentifier:ident];

	  ActActivityListItemView *view
	    = [[ActActivityListItemView alloc] init];

	  view.frame = cell.contentView.bounds;
	  view.autoresizingMask = (UIViewAutoresizingFlexibleWidth
				   | UIViewAutoresizingFlexibleHeight);
	  [cell.contentView addSubview:view];
	}
      else if ([ident isEqualToString:@"weekCell"])
	{
	  /* FIXME: implement this. */
	  cell = [[UITableViewCell alloc] initWithStyle:
		  UITableViewCellStyleDefault reuseIdentifier:ident];
	  cell.textLabel.text = @"Week Cell";
	}
      else if ([ident isEqualToString:@"loadMoreCell"])
	{
	  cell = [[ActActivityLoadMoreCell alloc] initWithStyle:
		  UITableViewCellStyleDefault reuseIdentifier:ident];
	  cell.textLabel.text = @"Load More Activities";
	}
    }

  if ([ident isEqualToString:@"activityCell"])
    {
      ActActivityListItemView *view
        = (id)[cell.contentView.subviews firstObject];
      view.listItem = [self listItemForIndex:path.row];
    }
  else if ([ident isEqualToString:@"weekCell"])
    {
    }
  else if ([ident isEqualToString:@"loadMoreCell"])
    {
      ActActivityLoadMoreCell *mc = (id)cell;
      mc.earliestTime = _earliestTime;
    }

  return cell;
}

/* UITableViewDelegate methods. */

- (CGFloat)tableView:(UITableView *)tv
    heightForRowAtIndexPath:(NSIndexPath *)path
{
  if (path.section == 0 && _viewMode == ActActivitiesViewList)
    {
      act::activity_list_item_ref item = [self listItemForIndex:path.row];
      CGFloat width = tv.bounds.size.width;
      item->update_height(width);
      return item->height;
    }
  else
    return tv.rowHeight;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)path
{
  UITableViewCell *cell = [tv cellForRowAtIndexPath:path];

  NSString *ident = cell.reuseIdentifier;

  if ([ident isEqualToString:@"activityCell"])
    {
      act::activity_list_item_ref item = [self listItemForIndex:path.row];

      ActActivityViewController *controller
        = [ActActivityViewController instantiate];

      controller.activityStorage = item->activity->storage();

      UINavigationController *nav = (id)self.parentViewController;

      [nav pushViewController:controller animated:YES];
    }
  else if ([ident isEqualToString:@"weekCell"])
    {
      /* FIXME: something? */
    }
  else if ([ident isEqualToString:@"loadMoreCell"])
    {
      ActActivityLoadMoreCell *mc = (id)cell;
      [self loadMoreData:mc.earliestTime];
    }

  [tv deselectRowAtIndexPath:path animated:NO];
}

@end

@implementation ActActivityLoadMoreCell
@synthesize earliestTime = _earliestTime;
@end
