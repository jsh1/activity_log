// -*- c-style: gnu -*-

#import "ActActivityLapView.h"

#import "ActActivityView.h"

#import "act-format.h"

#define TOP_BORDER 0
#define BOTTOM_BORDER 0
#define LEFT_BORDER 32
#define RIGHT_BORDER 32

#define HEADER_HEIGHT 20
#define ROW_HEIGHT 20
#define SEPARATOR_HEIGHT 2
#define COLUMN_WIDTH 80

@implementation ActActivityLapView

static void
addTableColumn (NSTableView *tv, NSFont *font,
		NSString *ident, NSString *title)
{
  NSTableColumn *tc = [[NSTableColumn alloc] initWithIdentifier:ident];
  [tc setEditable:NO];
  [[tc headerCell] setStringValue:title];
  [[tc headerCell] setFont:font];
  [[tc dataCell] setFont:font];
  [tv addTableColumn:tc];
  [tc release];
}

- (void)createTableView
{
  NSFont *font = [[self activityView] font];

  _headerView = [[NSTableHeaderView alloc] initWithFrame:NSZeroRect];
  [self addSubview:_headerView];
  [_headerView release];

  _tableView = [[NSTableView alloc] initWithFrame:NSZeroRect];
  [_tableView setDataSource:self];
  [_tableView setDelegate:self];
  [_tableView setUsesAlternatingRowBackgroundColors:YES];
  [_tableView setRowHeight:ROW_HEIGHT];

  addTableColumn(_tableView, font, @"lap", @"Lap");
  addTableColumn(_tableView, font, @"distance", @"Distance");
  addTableColumn(_tableView, font, @"duration", @"Duration");
  addTableColumn(_tableView, font, @"pace", @"Pace");
  addTableColumn(_tableView, font, @"average-hr", @"Avg HR");
  addTableColumn(_tableView, font, @"max-hr", @"Max HR");

  [self addSubview:_tableView];
  [_tableView release];

  [_headerView setTableView:_tableView];
}

- (void)activityDidChange
{
  if (_tableView == nil && [self numberOfRowsInTableView:nil] != 0)
    [self createTableView];

  bool has_hr = false;

  if (const act::activity *a = [[self activityView] activity])
    {
      if (const act::gps::activity *gps_data = a->gps_data())
	has_hr = gps_data->has_heart_rate();
    }

  [[_tableView tableColumnWithIdentifier:@"average-hr"] setHidden:!has_hr];
  [[_tableView tableColumnWithIdentifier:@"max-hr"] setHidden:!has_hr];

  [_tableView reloadData];
}

- (NSEdgeInsets)edgeInsets
{
  return NSEdgeInsetsMake(TOP_BORDER, LEFT_BORDER,
			  BOTTOM_BORDER, RIGHT_BORDER);
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
  NSInteger rows = [self numberOfRowsInTableView:_tableView];
  if (rows == 0)
    return 0;

  if (_tableView == nil)
    [self createTableView];

  return HEADER_HEIGHT + (ROW_HEIGHT + SEPARATOR_HEIGHT) * rows;
}

- (void)layoutSubviews
{
  NSInteger rows = [self numberOfRowsInTableView:_tableView];
  if (rows == 0)
    return;

  if (_tableView == nil)
    [self createTableView];

  for (NSTableColumn *col in [_tableView tableColumns])
    [col setWidth:COLUMN_WIDTH];

  NSRect r = [self bounds];

  r.size.height = (ROW_HEIGHT + SEPARATOR_HEIGHT) * rows;
  [_tableView setFrame:r];
  [_tableView sizeLastColumnToFit];

  r = [_tableView frame];
  r.origin.y += r.size.height;
  r.size.height = HEADER_HEIGHT;
  [_headerView setFrame:r];
}

// NSTableViewDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
  const act::activity *a = [[self activityView] activity];
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
  const act::activity *a = [[self activityView] activity];
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
  [[self activityView] setSelectedLapIndex:[_tableView selectedRow]];
}

@end
