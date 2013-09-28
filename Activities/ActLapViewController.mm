// -*- c-style: gnu -*-

#import "ActLapViewController.h"

#import "ActWindowController.h"

#import "act-format.h"

@implementation ActLapViewController

+ (NSString *)viewNibName
{
  return @"ActLapView";
}

- (void)viewDidLoad
{
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:_controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedLapIndexDidChange:)
   name:ActSelectedActivityDidChange object:_controller];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  [_tableView reloadData];
}

- (void)selectedLapIndexDidChange:(NSNotification *)note
{
  NSInteger row = [_controller selectedLapIndex];
  NSIndexSet *set = nil;

  if (row >= 0)
    {
      if (row != [_tableView selectedRow])
	set = [NSIndexSet indexSetWithIndex:row];
    }
  else
    set = [NSIndexSet indexSet];

  if (set != nil)
    [_tableView selectRowIndexes:set byExtendingSelection:NO];
}

// NSTableViewDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
  const act::activity *a = [_controller selectedActivity];
  if (!a)
    return 0;

  const act::gps::activity *gps_data = a->gps_data();
  if (!gps_data)
    return 0;

  return gps_data->laps().size();
}

- (id)tableView:(NSTableView *)tv
  objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
  const act::activity *a = [_controller selectedActivity];
  if (!a)
    return nil;

  const act::gps::activity *gps_data = a->gps_data();
  if (!gps_data)
    return nil;

  if (row < 0 || row >= gps_data->laps().size())
    return nil;

  const act::gps::activity::lap &lap = gps_data->laps()[row];

  std::string str;
  NSString *ident = [col identifier];

  if ([ident isEqualToString:@"lap"])
    return [NSString stringWithFormat:@"%d", (int) row + 1];
  else if ([ident isEqualToString:@"date"])
    act::format_date_time(str, (time_t) lap.time, "%F %-l%p");
  else if ([ident isEqualToString:@"distance"])
    act::format_distance(str, lap.distance, act::unit_type::unknown);
  else if ([ident isEqualToString:@"duration"])
    act::format_duration(str, lap.duration);
  else if ([ident isEqualToString:@"pace"] && lap.avg_speed != 0)
    act::format_pace(str, lap.avg_speed, act::unit_type::unknown);
  else if ([ident isEqualToString:@"max-pace"] && lap.max_speed != 0)
    act::format_pace(str, lap.max_speed, act::unit_type::unknown);
  else if ([ident isEqualToString:@"speed"] && lap.avg_speed != 0)
    act::format_speed(str, lap.avg_speed, act::unit_type::unknown);
  else if ([ident isEqualToString:@"max-speed"] && lap.max_speed != 0)
    act::format_speed(str, lap.max_speed, act::unit_type::unknown);
  else if ([ident isEqualToString:@"average-hr"] && lap.avg_heart_rate != 0)
    act::format_number(str, lap.avg_heart_rate);
  else if ([ident isEqualToString:@"max-hr"] && lap.max_heart_rate != 0)
    act::format_number(str, lap.max_heart_rate);
  else if ([ident isEqualToString:@"calories"] && lap.calories != 0)
    act::format_number(str, lap.calories);

  if (str.size() != 0)
    return [NSString stringWithUTF8String:str.c_str()];
  else
    return nil;
}

// NSTableViewDelegate methods

- (void)tableViewSelectionDidChange:(NSNotification *)note
{
  [_controller setSelectedLapIndex:[_tableView selectedRow]];
}

@end
