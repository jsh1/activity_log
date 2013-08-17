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

  std::string str;

  NSString *ident = [col identifier];
  const char *string_field = nullptr;

  if ([ident isEqualToString:@"date"])
    act::format_date_time(str, a.date(), "%F %-l%p");
  else if ([ident isEqualToString:@"distance"] && a.distance() != 0)
    act::format_distance(str, a.distance(), a.distance_unit());
  else if ([ident isEqualToString:@"duration"] && a.duration() != 0)
    act::format_duration(str, a.duration());
  else if ([ident isEqualToString:@"pace"] && a.speed() != 0)
    act::format_pace(str, a.speed(), a.speed_unit());
  else if ([ident isEqualToString:@"speed"] && a.speed() != 0)
    act::format_speed(str, a.speed(), a.speed_unit());
  else if ([ident isEqualToString:@"activity"])
    string_field = "activity";
  else if ([ident isEqualToString:@"type"])
    string_field = "type";
  else if ([ident isEqualToString:@"course"])
    string_field = "course";

  if (string_field != nullptr)
    {
      if (const std::string *s = a.field_ptr(string_field))
	return [NSString stringWithUTF8String:s->c_str()];
    }

  return [NSString stringWithUTF8String:str.c_str()];
}

// NSTableViewDelegate methods

- (void)tableViewSelectionDidChange:(NSNotification *)note
{
  NSInteger row = [_tableView selectedRow];

  if (row >= 0 && row < _activities.size())
    [_controller setSelectedActivity:_activities[row]];
}

@end
