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

#import "ActListViewController.h"

#import "ActAppDelegate.h"
#import "ActWindowController.h"

#import "AppKitExtensions.h"

#import "act-format.h"

#import <algorithm>

@implementation ActListViewController
{
  std::unordered_map<act::activity_storage_ref,
    std::unique_ptr<act::activity>> _activity_cache;
}

@synthesize tableView = _tableView;

+ (NSString *)viewNibName
{
  return @"ActListView";
}

- (void)viewDidLoad
{
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityListDidChange:)
   name:ActActivityListDidChange object:self.controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:self.controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeField:)
   name:ActActivityDidChangeField object:self.controller];

  for (NSTableColumn *col in _tableView.tableColumns)
    ((NSCell *)col.dataCell).verticallyCentered = YES;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [NSRunLoop cancelPreviousPerformRequestsWithTarget:self];

}

- (NSView *)initialFirstResponder
{
  return _tableView;
}

- (NSInteger)rowForActivityStorage:(const act::activity_storage_ref)storage
{
  if (storage == nullptr)
    return NSNotFound;

  const std::vector<act::database::item> &vec = self.controller.activityList;

  const auto &pos = std::find_if(vec.begin(), vec.end(),
				 [=] (const act::database::item &a) {
				   return a.storage() == storage;
				 });

  if (pos != vec.end())
    return pos - vec.begin();
  else
    return NSNotFound;
}

- (act::activity *)activityForRow:(NSInteger)row
{
  const auto &vec = self.controller.activityList;

  act::activity_storage_ref storage = vec[row].storage();

  act::activity *a = _activity_cache[storage].get();

  if (a == nullptr)
    {
      a = new act::activity(storage);
      _activity_cache[storage].reset(a);
    }

  // FIXME: flush cache periodically?

  return a;
}

- (void)activityListDidChange:(NSNotification *)note
{
  [_tableView reloadData];
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  NSInteger newRow = [self rowForActivityStorage:
		      self.controller.selectedActivityStorage];

  NSIndexSet *set = nil;

  if (newRow != NSNotFound)
    {
      if (newRow != _tableView.selectedRow)
	set = [NSIndexSet indexSetWithIndex:newRow];
    }
  else
    set = [NSIndexSet indexSet];

  if (set != nil)
    [_tableView selectRowIndexes:set byExtendingSelection:NO];

  [_tableView scrollRectToVisible:[_tableView rectOfRow:newRow]];
}

- (void)activityDidChangeField:(NSNotification *)note
{
  void *ptr = [note.userInfo[@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);

  NSInteger row = [self rowForActivityStorage:a];
  if (row == NSNotFound)
    return;

  [_tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
   columnIndexes:[NSIndexSet indexSetWithIndexesInRange:
		  NSMakeRange(0, _tableView.numberOfColumns)]];
}

// NSTableViewDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
  return self.controller.activityList.size();
}

- (id)tableView:(NSTableView *)tv
  objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
  const act::activity *a = [self activityForRow:row];

  NSString *ident = col.identifier;

  if ([ident isEqualToString:@"date"])
    {
      static NSDateFormatter *formatter;

      if (formatter == nil)
	{
	  NSLocale *locale
	    = ((ActAppDelegate *)NSApp.delegate).currentLocale;
	  formatter = [[NSDateFormatter alloc] init];
	  formatter.locale = locale;
	  formatter.dateFormat = 
	   [NSDateFormatter dateFormatFromTemplate:@"d/M/yy ha"
	    options:0 locale:locale];
	}

      return [formatter stringFromDate:
	      [NSDate dateWithTimeIntervalSince1970:(time_t)a->date()]];
    }
  else
    return [self.controller stringForField:ident ofActivity:*a];
}

- (void)tableView:(NSTableView *)tv setObjectValue:(id)object
    forTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
  act::activity *a = [self activityForRow:row];

  NSString *ident = col.identifier;

  if ([ident isEqualToString:@"date"])
    return;
  else
    [self.controller setString:object forField:ident ofActivity:*a];
}

// NSTableViewDelegate methods

- (void)tableViewSelectionDidChange:(NSNotification *)note
{
  NSInteger row = _tableView.selectedRow;
  const auto &activities = self.controller.activityList;

  if (row >= 0 && row < activities.size())
    self.controller.selectedActivityStorage = activities[row].storage();
  else
    self.controller.selectedActivityStorage = nullptr;
}

@end
