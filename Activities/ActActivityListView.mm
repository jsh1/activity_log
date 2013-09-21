// -*- c-style: gnu -*-

#import "ActActivityListView.h"

#import "ActWindowController.h"

#import "act-format.h"

#import <algorithm>

@implementation ActActivityListView

- (void)dealloc
{
  [NSRunLoop cancelPreviousPerformRequestsWithTarget:self];

  [super dealloc];
}

- (const std::vector<act::activity_storage_ref> &)activities
{
  return _activities;
}

- (void)setActivities:(const std::vector<act::activity_storage_ref> &)vec
{
  _activities = vec;

  _activity_cache.clear();
  _activity_cache.resize(vec.size());

  [_tableView reloadData];
}

- (NSInteger)rowForActivity:(const act::activity_storage_ref)storage
{
  const auto &pos = std::find(_activities.begin(), _activities.end(), storage);

  if (pos != _activities.end())
    return pos - _activities.begin();
  else
    return NSNotFound;
}

- (act::activity_storage_ref)selectedActivity
{
  NSInteger row = [_tableView selectedRow];

  if (row >= 0 && row < _activities.size())
    return _activities[row];
  else
    return act::activity_storage_ref();
}

- (void)setSelectedActivity:(act::activity_storage_ref)storage
{
  NSIndexSet *set = nil;

  NSInteger newRow = [self rowForActivity:storage];
  if (newRow != NSNotFound)
    {
      if (newRow != [_tableView selectedRow])
	set = [NSIndexSet indexSetWithIndex:newRow];
    }
  else
    set = [NSIndexSet indexSet];

  if (set != nil)
    [_tableView selectRowIndexes:set byExtendingSelection:NO];
}

- (void)reloadActivity:(const act::activity_storage_ref)storage
{
  NSInteger row = [self rowForActivity:storage];
  if (row == NSNotFound)
    return;

  [_tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
   columnIndexes:[NSIndexSet indexSetWithIndexesInRange:
		  NSMakeRange(0, [_tableView numberOfColumns])]];
}

- (act::activity *)activityForRow:(NSInteger)row
{
  if (_activity_cache[row] == nullptr)
    _activity_cache[row].reset(new act::activity(_activities[row]));

  // FIXME: flush cache periodically?

  return _activity_cache[row].get();
}

// NSTableViewDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
  return _activities.size();
}

- (id)tableView:(NSTableView *)tv
  objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
  const act::activity *a = [self activityForRow:row];

  NSString *ident = [col identifier];

  if ([ident isEqualToString:@"date"])
    {
      std::string str;
      act::format_date_time(str, a->date(), "%D %-l%p");
      return [NSString stringWithUTF8String:str.c_str()];
    }
  else
    return [_controller stringForField:ident ofActivity:*a];
}

- (void)tableView:(NSTableView *)tv setObjectValue:(id)object
    forTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
  act::activity *a = [self activityForRow:row];

  NSString *ident = [col identifier];

  if ([ident isEqualToString:@"date"])
    return;
  else
    [_controller setString:object forField:ident ofActivity:*a];
}

// NSTableViewDelegate methods

- (void)tableViewSelectionDidChange:(NSNotification *)note
{
  NSInteger row = [_tableView selectedRow];

  if (row >= 0 && row < _activities.size())
    [_controller setSelectedActivity:_activities[row]];
  else
    [_controller setSelectedActivity:nullptr];
}

@end
