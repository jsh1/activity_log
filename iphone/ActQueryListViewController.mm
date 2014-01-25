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

#import "ActQueryListViewController.h"

#import "ActActivitiesViewController.h"
#import "ActDatabaseManager.h"
#import "ActSettingsViewController.h"

#import "act-util.h"

#import "DropboxSDK.h"

#import <xlocale.h>

@implementation ActQueryListViewController

+ (ActQueryListViewController *)instantiate
{
  return [[[NSBundle mainBundle] loadNibNamed:
	   @"QueryListView" owner:self options:nil] firstObject];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
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
}

- (void)viewWillAppear:(BOOL)animated
{
  [self reloadData];
}

- (void)pushAllActivitiesAnimated:(BOOL)flag
{
  time_t start = 0;
  time_t end = time(nullptr);

  act::database::query query;
  query.add_date_range(act::date_range(start, end - start));

  ActActivitiesViewController *activities
    = [ActActivitiesViewController instantiate];

  activities.query = query;
  activities.title = @"All Activities";

  UINavigationController *nav = (id)self.parentViewController;

  [nav pushViewController:activities animated:flag];
}

- (int)year
{
  return _year;
}

- (void)setYear:(int)x
{
  if (_year != x)
    {
      _year = x;
      _rowData = nil;
      [self reloadData];
    }
}

static NSInteger
reverse_compare(id a, id b, void *ctx)
{
  return [b compare:a];
}

- (void)reloadData
{
  ActDatabaseManager *db = [ActDatabaseManager sharedManager];

  NSString *path = @"";

  if (_year != 0)
    {
      char buf[64];
      snprintf_l(buf, sizeof(buf), nullptr, "%d", _year);
      path = [NSString stringWithUTF8String:buf];
    }

  if (NSDictionary *dict = [db activityMetadataForPath:path])
    {
      NSMutableArray *array = [NSMutableArray array];

      for (NSDictionary *sub_dict in dict[@"contents"])
	{
	  if (![sub_dict[@"directory"] boolValue])
	    continue;

	  int value = [sub_dict[@"name"] intValue];

	  if (value > 0)
	    {
	      if (_year != 0)
		value--;		/* month is 0.. indexed */

	      [array addObject:@(value)];
	    }
	}
      [array sortUsingFunction:reverse_compare context:nullptr];

      if (![_rowData isEqual:array])
	{
	  _rowData = array;

	  [self.tableView reloadData];
	}
    }
}

- (void)metadataCacheDidChange:(NSNotification *)note
{
  [self reloadData];
}

- (void)activityDatabaseDidChange:(NSNotification *)note
{
  [self reloadData];
}

- (IBAction)configAction:(id)sender
{
  UINavigationController *settings_nav
    = [[UINavigationController alloc]
       initWithRootViewController:[ActSettingsViewController instantiate]];

  UINavigationController *main_nav = (id)self.parentViewController;

  [main_nav presentViewController:settings_nav animated:YES completion:nil];
}

/* UITableViewDataSource methods. */

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
  return 2;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec
{
  if (sec == 0)
    return 1;
  else
    return [_rowData count];
}

- (UITableViewCell *)tableView:(UITableView *)tv
    cellForRowAtIndexPath:(NSIndexPath *)path
{
  NSString *ident = @"queryCell";

  UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];

  if (cell == nil)
    {
      cell = [[UITableViewCell alloc] initWithStyle:
	      UITableViewCellStyleDefault reuseIdentifier:ident];
    }

  if (path.section == 0)
    cell.textLabel.text = @"All Activities";
  else
    {
      NSNumber *value = _rowData[path.row];
      if (_year == 0)
	cell.textLabel.text = [value stringValue];
      else
	{
	  static NSDateFormatter *formatter;
	  if (formatter == nil)
	    formatter = [[NSDateFormatter alloc] init];
	  NSArray *names = [formatter standaloneMonthSymbols];
	  int month = [value intValue];
	  cell.textLabel.text = names[month];
	}
    }

  return cell;
}

/* UITableViewDelegate methods. */

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)path
{
  UIViewController *next_controller = nil;

  if (path.section == 0 || _year != 0)
    {
      using act::year_time;
      using act::month_time;

      time_t start = 0, end = 0;

      if (path.section == 0)
	{
	  if (_year == 0)
	    start = 0, end = time(nullptr);
	  else
	    start = year_time(_year), end = year_time(_year + 1);
	}
      else
	{
	  int arg = [_rowData[path.row] intValue];
	  if (_year == 0)
	    start = year_time(arg), end = year_time(arg + 1);
	  else
	    start = month_time(_year, arg), end = month_time(_year, arg + 1);
	}
    
      act::database::query query;
      query.add_date_range(act::date_range(start, end - start));

      ActActivitiesViewController *activities
	= [ActActivitiesViewController instantiate];

      activities.query = query;

      next_controller = activities;
    }
  else
    {
      ActQueryListViewController *query
	= [ActQueryListViewController instantiate];

      query.year = [_rowData[path.row] intValue];

      next_controller = query;
    }

  next_controller.title = [tv cellForRowAtIndexPath:path].textLabel.text;

  UINavigationController *nav = (id)self.parentViewController;

  [nav pushViewController:next_controller animated:YES];

  [tv deselectRowAtIndexPath:path animated:NO];
}

@end
