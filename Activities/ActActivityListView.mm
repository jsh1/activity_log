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

- (void)reloadSelectedActivity
{
  NSInteger row = [_tableView selectedRow];
  if (row < 0)
    return;

  [_tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
   columnIndexes:[NSIndexSet indexSetWithIndexesInRange:
		  NSMakeRange(0, [_tableView numberOfColumns])]];
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
  else if ([ident isEqualToString:@"max-pace"] && a.max_speed() != 0)
    act::format_pace(str, a.max_speed(), a.max_speed_unit());
  else if ([ident isEqualToString:@"speed"] && a.speed() != 0)
    act::format_speed(str, a.speed(), a.speed_unit());
  else if ([ident isEqualToString:@"max-speed"] && a.max_speed() != 0)
    act::format_speed(str, a.max_speed(), a.max_speed_unit());
  else if ([ident isEqualToString:@"effort"] && a.effort() != 0)
    act::format_fraction(str, a.effort());
  else if ([ident isEqualToString:@"quality"] && a.quality() != 0)
    act::format_fraction(str, a.quality());
  else if ([ident isEqualToString:@"average-hr"] && a.average_hr() != 0)
    act::format_number(str, a.average_hr());
  else if ([ident isEqualToString:@"max-hr"] && a.max_hr() != 0)
    act::format_number(str, a.max_hr());
  else if ([ident isEqualToString:@"resting-hr"] && a.resting_hr() != 0)
    act::format_number(str, a.resting_hr());
  else if ([ident isEqualToString:@"calories"] && a.calories() != 0)
    act::format_number(str, a.calories());
  else if ([ident isEqualToString:@"weight"] && a.weight() != 0)
    act::format_weight(str, a.weight(), a.weight_unit());
  else if ([ident isEqualToString:@"temperature"] && a.temperature() != 0)
    act::format_temperature(str, a.temperature(), a.temperature_unit());
  else if ([ident isEqualToString:@"dew-point"] && a.dew_point() != 0)
    act::format_temperature(str, a.dew_point(), a.dew_point_unit());
  else if ([ident isEqualToString:@"weather"])
    act::format_keywords(str, a.weather());
  else if ([ident isEqualToString:@"equipment"])
    act::format_keywords(str, a.equipment());
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
  else
    [_controller setSelectedActivity:nullptr];
}

@end
