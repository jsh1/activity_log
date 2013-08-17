// -*- c-style: gnu -*-

#import "ActActivityListView.h"

#import "act-format.h"

#import <algorithm>

@implementation ActActivityListView

- (const std::vector<act::activity_storage_ref> &)activities
{
  return _activities;
}

- (void)setActivities:(const std::vector<act::activity_storage_ref> &)vec
{
  _activities = vec;

  [_tableView reloadData];
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
  const auto &pos = std::find(_activities.begin(), _activities.end(), storage);
  if (pos == _activities.end())
    return;

  NSInteger newRow = pos - _activities.begin();
  NSInteger oldRow = [_tableView selectedRow];

  if (newRow != oldRow)
    {
      [_tableView selectRowIndexes:
       [NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
    }
}

// NSTableViewDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
  return _activities.size();
}

- (id)tableView:(NSTableView *)tv
  objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
  const act::activity_storage_ref &storage = _activities[row];

  // FIXME: bootstrap hacking

  act::activity a (storage);

  std::string date_str;
  act::format_date_time(date_str, a.date());

  return [NSString stringWithUTF8String:date_str.c_str()];
}

// NSTableViewDelegate methods

- (void)tableViewSelectionDidChange:(NSNotification *)note
{
  NSInteger row = [_tableView selectedRow];

  if (row >= 0 && row < _activities.size())
    [_controller setSelectedActivity:_activities[row]];
}

@end
