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

#import "act-activity-list-item.h"
#import "act-activity-list-section.h"

#import "act-util.h"

#import <time.h>
#import <xlocale.h>

@interface ActActivityLoadMoreCell : UITableViewCell
@property(nonatomic) time_t earliestTime;
@end

@interface ActActivitiesViewController () <UIViewControllerPreviewingDelegate>
@end

@implementation ActActivitiesViewController
{
  act::database::query _query;
  NSInteger _viewMode;

  std::vector<act::database::item> _items;
  std::vector<act::activity_list_section> _listData;

  time_t _earliestTime;
  BOOL _moreItems;
  BOOL _needReloadView;

  int _ignoreNotifications;

  UIBarButtonItem *_addItem;
  UIBarButtonItem *_weekItem;

  id <UIViewControllerPreviewing> _forceTouchContext;
}

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

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(metadataCacheDidChange:)
   name:ActMetadataCacheDidChange object:nil];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDatabaseDidChange:)
   name:ActActivityDatabaseDidChange object:nil];

  _addItem = [[UIBarButtonItem alloc]
	initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
	target:self action:@selector(addActivityAction:)];

  _weekItem = [[UIBarButtonItem alloc]
	initWithTitle:@"Week" style:UIBarButtonItemStylePlain
	target:self action:@selector(toggleWeekAction:)];

  [[self navigationItem] setRightBarButtonItems:@[_addItem, _weekItem]];

  self.automaticallyAdjustsScrollViewInsets = NO;

  if (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable)
    {
      _forceTouchContext =
        [self registerForPreviewingWithDelegate:self sourceView:self.view];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)old
{
  UIForceTouchCapability oldCap = old.forceTouchCapability;
  UIForceTouchCapability newCap = self.traitCollection.forceTouchCapability;

  if (oldCap != newCap)
    {
      if (_forceTouchContext)
	{
	  [self unregisterForPreviewingWithContext:_forceTouchContext];
	  _forceTouchContext = nil;
	}

      if (newCap == UIForceTouchCapabilityAvailable)
	{
	  _forceTouchContext =
	    [self registerForPreviewingWithDelegate:self sourceView:self.view];
	}
    }
}

- (void)viewWillAppear:(BOOL)animated
{
  [self reloadData];
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
  ActAppDelegate *delegate = (id)[UIApplication sharedApplication].delegate;
  ActFileManager *fm = [ActFileManager sharedManager];
  ActDatabaseManager *dbm = [ActDatabaseManager sharedManager];

  if (dbm != nil)
    {
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
	      time_t month_end = (month_start
				  + act::seconds_in_month(year, month));

	      if (!(month_end > min_time))
		break;

	      char buf[64];
	      snprintf_l(buf, sizeof(buf), nullptr,
			 "%d/%02d", year, month + 1);

	      NSString *dir = [NSString stringWithUTF8String:buf];

	      NSDictionary *dict = [fm metadataForRemotePath:
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

		  [dbm loadActivityFromPath:path revision:rev];
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
      dbm.database->execute_query(query_copy, items);

      if (_items != items)
	{
	  using std::swap;
	  swap(_items, items);
	  _listData.clear();
	  _needReloadView = YES;
	}
    }
  else
    {
      if (_listData.size() != 0)
	{
	  _listData.clear();
	  _needReloadView = YES;
	}
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

  time_t week_start = LONG_MAX;

  for (auto &it : _items)
    {
      time_t date = it.date();

      if (date < week_start)
	{
	  int week = act::week_index(date);
	  week_start = act::week_date(week);
	  _listData.emplace_back(week_start);
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

- (void)willAnimateRotationToInterfaceOrientation:
    (UIInterfaceOrientation)orientation duration:(NSTimeInterval)dur
{
  [self.tableView reloadData];
  _needReloadView = NO;
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

  UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];

  if (cell == nil)
    {
      if ([ident isEqualToString:@"activityCell"])
	{
	  cell = [[UITableViewCell alloc] initWithStyle:
		  UITableViewCellStyleDefault reuseIdentifier:ident];

	  ActActivityListItemView *view
	    = [[ActActivityListItemView alloc] init];

	  view.contentMode = UIViewContentModeRedraw;
	  view.autoresizingMask = (UIViewAutoresizingFlexibleWidth
				   | UIViewAutoresizingFlexibleHeight);
	  view.frame = cell.contentView.bounds;
	  [cell.contentView addSubview:view];
	}
      else if ([ident isEqualToString:@"loadMoreCell"])
	{
	  cell = [[ActActivityLoadMoreCell alloc] initWithStyle:
		  UITableViewCellStyleDefault reuseIdentifier:ident];
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

      if (sec <= _listData.size())
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

      NSString *ident = @"listHeader";

      UITableViewHeaderFooterView *view
        = [tv dequeueReusableHeaderFooterViewWithIdentifier:ident];

      if (view == nil)
	{
	  view = [[UITableViewHeaderFooterView alloc]
		  initWithReuseIdentifier:ident];
	}

      if (sec < _listData.size())
	_listData[sec].configure_view(view);
      else
	view.textLabel.text = @"More";

      return view;
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

/* UIViewControllerPreviewingDelegate methods. */

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)ctx
  viewControllerForLocation:(CGPoint)loc
{
  UITableView *tv = self.tableView;

  NSIndexPath *path = [tv indexPathForRowAtPoint:loc];
  if (path == nil)
    return nil;

  UITableViewCell *cell = [tv cellForRowAtIndexPath:path];
  if (![cell.reuseIdentifier isEqualToString:@"activityCell"])
    return nil;

  if (_listData.size() == 0)
    [self updateListData];

  /* FIXME: copy-paste from above. */

  act::activity_list_item_ref item = _listData[path.section].items[path.row];

  ActActivityViewController *controller
    = [ActActivityViewController instantiate];

  controller.activityStorage = item->activity->storage();

  controller.preferredContentSize = CGSizeZero;
  ctx.sourceRect = cell.frame;

  return controller;
}

- (void)previewingContext:(id<UIViewControllerPreviewing>)ctx
  commitViewController:(UIViewController *)controller
{
  [self.navigationController pushViewController:controller animated:NO];
}

@end

@implementation ActActivityLoadMoreCell

@synthesize earliestTime = _earliestTime;

- (void)setEarliestTime:(time_t)t
{
  static NSDateFormatter *formatter;

  if (_earliestTime == t)
    return;

  _earliestTime = t;

  if (formatter == nil)
    {
      formatter = [[NSDateFormatter alloc] init];
      formatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:
			      @"MMMM" options:0 locale:nil];
    }

  NSDate *date = [NSDate dateWithTimeIntervalSince1970:t - 15 * 86400];
  self.textLabel.text = [NSString stringWithFormat:
			 @"Load %@ Activities…",
			 [formatter stringFromDate:date]];
}

@end
