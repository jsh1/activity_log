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
#import "ActAppDelegate.h"
#import "ActDatabaseManager.h"
#import "ActFileManager.h"

#import "act-util.h"

#import <time.h>
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

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  _database = [[ActDatabaseManager alloc]
	       initWithFileManager:[ActFileManager sharedManager]];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(metadataCacheDidChange:)
   name:ActMetadataCacheDidChange object:_database.fileManager];
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDatabaseDidChange:)
   name:ActActivityDatabaseDidChange object:_database];

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
  /* Pull activity files spanning the query's partial date range into
     the database. */

  _ignoreNotifications++;

  act::date_range range;
  for (const auto &it : _query.date_ranges())
    range.merge(it);

  if (!range.is_empty())
    {
      ActAppDelegate *delegate
	= (id)[UIApplication sharedApplication].delegate;

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

	  NSDictionary *dict = [_database.fileManager metadataForRemotePath:
				[delegate remoteActivityPath:dir]];

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

	      [_database loadActivityFromPath:path revision:rev];
	    }

	  month--;
	}

      _moreItems = _earliestTime > range.start;
    }

  _ignoreNotifications--;

  /* Reload the query results and update the table view. Restrict 
     the query to only return results until _earliestTime, to avoid
     over-filling the table initially. */

  act::database::query query_copy(_query);
  time_t now = time(nullptr);
  act::date_range query_range(_earliestTime, now - _earliestTime);

  for (auto &it : query_copy.date_ranges())
    it.intersect(query_range);

  std::vector<act::database::item> items;
  _database.database->execute_query(query_copy, items);

  if (_items != items)
    {
      using std::swap;
      swap(_items, items);
      _listData.clear();
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

- (void)updateListData
{
  if (_listData.size() != 0)
    return;

  time_t month_start = LONG_MAX;

  for (auto &it : _items)
    {
      time_t date = it.date();

      if (date < month_start)
	{
	  struct tm tm = {0};
	  localtime_r(&date, &tm);
	  month_start = act::month_time(tm.tm_year + 1900, tm.tm_mon);
	  _listData.emplace_back(month_start);
	}

      _listData.back().items.emplace_back(new act::activity_list_item(it.storage()));
    }
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
  if (_viewMode == ActActivitiesViewList)
    {
      if (_listData.size() == 0)
	[self updateListData];

      return _listData.size() + (_moreItems ? 1 : 0);
    }
  else
    return 0;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec
{
  if (_viewMode == ActActivitiesViewList)
    {
      if (_listData.size() == 0)
	[self updateListData];

      if (sec < _listData.size())
	return _listData[sec].items.size();
      else
	return 1;
    }
  else
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tv
    cellForRowAtIndexPath:(NSIndexPath *)path
{
  NSString *ident;
  UITableViewCell *cell;

  if (_viewMode == ActActivitiesViewList)
    {
      if (_listData.size() == 0)
	[self updateListData];

      if (path.section < _listData.size())
	ident = @"activityCell";
      else
	ident = @"loadMoreCell";
    }
  else
    ident = nil;

  if (ident == nil)
    return nil;

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
      view.listItem = _listData[path.section].items[path.row];
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
    estimatedHeightForRowAtIndexPath:(NSIndexPath *)path
{
  if (_viewMode == ActActivitiesViewList)
    {
      if (_listData.size() == 0)
	[self updateListData];

      if (path.section < _listData.size())
	return UITableViewAutomaticDimension;
    }

  return tv.rowHeight;
}

- (CGFloat)tableView:(UITableView *)tv
    heightForRowAtIndexPath:(NSIndexPath *)path
{
  if (_viewMode == ActActivitiesViewList)
    {
      if (_listData.size() == 0)
	[self updateListData];

      NSInteger sec = path.section;
      if (sec < _listData.size())
	{
	  act::activity_list_item_ref item = _listData[sec].items[path.row];
	  /* FIXME: not actually width of cell's contentView? */
	  CGFloat width = tv.bounds.size.width;
	  item->update_height(width);
	  return item->height;
	}
    }

  return tv.rowHeight;
}

- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)sec
{
  if (_viewMode == ActActivitiesViewList)
    {
      if (_listData.size() == 0)
	[self updateListData];

      if (sec < _listData.size())
	return tv.sectionHeaderHeight;
      else
	return 0;
    }

  return tv.sectionHeaderHeight;
}

- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)sec
{
  if (_viewMode == ActActivitiesViewList)
    {
      if (_listData.size() == 0)
	[self updateListData];

      if (sec < _listData.size())
	{
	  NSString *ident = @"listHeader";

	  UITableViewHeaderFooterView *view
	    = [tv dequeueReusableHeaderFooterViewWithIdentifier:ident];

	  if (view == nil)
	    {
	      view = [[UITableViewHeaderFooterView alloc]
		      initWithReuseIdentifier:ident];
	    }

	  _listData[sec].configure_view(view);

	  return view;
	}
    }

  return nil;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)path
{
  UITableViewCell *cell = [tv cellForRowAtIndexPath:path];

  NSString *ident = cell.reuseIdentifier;

  if ([ident isEqualToString:@"activityCell"])
    {
      if (_listData.size() == 0)
	[self updateListData];

      act::activity_list_item_ref item
	= _listData[path.section].items[path.row];

      ActActivityViewController *controller
	= [ActActivityViewController instantiate];

      controller.database = _database;
      controller.activityStorage = item->activity->storage();

      [self.navigationController pushViewController:controller animated:YES];
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
