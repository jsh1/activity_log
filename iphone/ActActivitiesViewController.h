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

#import <UIKit/UIKit.h>

#import "act-database.h"

#import "act-activity-list-item.h"
#import "act-activity-list-section.h"

enum
{
  ActActivitiesViewList,
  ActActivitiesViewWeek,
};

@class ActDatabaseManager;

@interface ActActivitiesViewController : UITableViewController
    <UITableViewDataSource, UITableViewDelegate>
{
  ActDatabaseManager *_database;

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
}

+ (ActActivitiesViewController *)instantiate;

@property(nonatomic) const act::database::query &query;

@property(nonatomic) NSInteger viewMode;

- (void)reloadData;

@end
