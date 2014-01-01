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

#import "ActLapViewController.h"

#import "ActCollapsibleView.h"
#import "ActTableView.h"
#import "ActWindowController.h"

#import "act-format.h"

#define HEADER_HEIGHT 16
#define ROW_HEIGHT 20
#define SEPARATOR_HEIGHT 2

@implementation ActLapViewController

+ (NSString *)viewNibName
{
  return @"ActLapView";
}

static void
addTableColumn (NSTableView *tv, NSFont *font, NSString *ident,NSString *title)
{
  NSTableColumn *tc = [[NSTableColumn alloc] initWithIdentifier:ident];
  [tc setEditable:NO];
  [[tc dataCell] setFont:font];
  [[tc dataCell] setVerticallyCentered:YES];
  NSTableHeaderCell *hc = [[NSTableHeaderCell alloc] initTextCell:title];
  [hc setFont:font];
  [tc setHeaderCell:hc];
  [hc release];
  [tv addTableColumn:tc];
  [tc release];
}

#if 0
static void
setTableColumnEnabled(NSTableView *tv, NSString *ident, BOOL state)
{
  [[tv tableColumnWithIdentifier:ident] setHidden:!state];
}
#endif

- (id)initWithController:(ActWindowController *)controller
    options:(NSDictionary *)opts
{
  self = [super initWithController:controller options:opts];
  if (self == nil)
    return nil;

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:_controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedLapIndexDidChange:)
   name:ActSelectedActivityDidChange object:_controller];

  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (void)viewDidLoad
{
  [(ActCollapsibleView *)[self view] setTitle:@"Laps"];

  // creating layers for each subview is not gaining us anything
  [[self view] setCanDrawSubviewsIntoLayer:YES];

  _headerView = [[NSTableHeaderView alloc] initWithFrame:NSZeroRect];
  [_lapView addSubview:_headerView];
  [_headerView release];

  _tableView = [[ActTableView alloc] initWithFrame:NSZeroRect];
  [_tableView setDataSource:self];
  [_tableView setDelegate:self];
  [_tableView setUsesAlternatingRowBackgroundColors:YES];
  [_tableView setRowHeight:ROW_HEIGHT];

  NSFont *font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
  addTableColumn(_tableView, font, @"lap", @"Lap");
  addTableColumn(_tableView, font, @"distance", @"Distance");
  addTableColumn(_tableView, font, @"duration", @"Duration");
  addTableColumn(_tableView, font, @"pace", @"Pace");
  addTableColumn(_tableView, font, @"max_pace", @"Max Pace");
  addTableColumn(_tableView, font, @"avg_hr", @"Avg HR");
  addTableColumn(_tableView, font, @"max_hr", @"Max HR");
  addTableColumn(_tableView, font, @"avg_cadence", @"Avg Cad.");
  addTableColumn(_tableView, font, @"max_cadence", @"Max Cad.");
  addTableColumn(_tableView, font, @"calories", @"Calories");
  addTableColumn(_tableView, font, @"avg_stance_time", @"Stance Time");
  addTableColumn(_tableView, font, @"avg_vertical_oscillation", @"Vert. Oscillation");

  [_lapView addSubview:_tableView];
  [_tableView release];

  [_headerView setTableView:_tableView];
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
#if 0
  const act::activity *a = [_controller selectedActivity];
  if (!a)
    return;

  const act::gps::activity *gps_a = a->gps_data();
  if (!gps_a)
    return;

  bool has_speed = gps_a->has_speed();
  bool has_hr = gps_a->has_heart_rate();
  bool has_altitude = gps_a->has_altitude();
  bool has_cadence = gps_a->has_cadence();
  bool has_dynamics = gps_a->has_dynamics();

  setTableColumnEnabled(_tableView, @"pace", has_speed);
  setTableColumnEnabled(_tableView, @"max_pace", has_speed);

  setTableColumnEnabled(_tableView, @"avg_hr", has_hr);
  setTableColumnEnabled(_tableView, @"max_hr", has_hr);

  setTableColumnEnabled(_tableView, @"ascent", has_altitude);
  setTableColumnEnabled(_tableView, @"descent", has_altitude);

  setTableColumnEnabled(_tableView, @"avg_cadence", has_cadence);
  setTableColumnEnabled(_tableView, @"max_cadence", has_cadence);

  setTableColumnEnabled(_tableView, @"avg_stance_time", has_dynamics);
  setTableColumnEnabled(_tableView, @"avg_vertical_oscillation", has_dynamics);
#endif

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

- (CGFloat)lapView_heightForWidth:(CGFloat)width
{
  NSInteger rows = [self numberOfRowsInTableView:_tableView];
  if (rows == 0)
    return 0;

  return (HEADER_HEIGHT - 1) + (ROW_HEIGHT + SEPARATOR_HEIGHT) * rows;
}

- (void)lapView_layoutSubviews
{
  NSInteger rows = [self numberOfRowsInTableView:_tableView];
  if (rows == 0)
    return;

  NSRect r = [_lapView bounds];

  r.size.height = (ROW_HEIGHT + SEPARATOR_HEIGHT) * rows;
  [_tableView setFrame:r];
  [_tableView sizeToFit];

  r.origin.y += r.size.height;
  r.size.height = HEADER_HEIGHT;
  [_headerView setFrame:r];
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
    act::format_date_time(str, (time_t) lap.start_time, "%F %-l%p");
  else if ([ident isEqualToString:@"distance"])
    act::format_distance(str, lap.total_distance, act::unit_type::unknown);
  else if ([ident isEqualToString:@"duration"])
    act::format_duration(str, lap.total_duration);
  else if ([ident isEqualToString:@"elapsed_time"])
    act::format_duration(str, lap.total_elapsed_time);
  else if ([ident isEqualToString:@"ascent"])
    act::format_duration(str, lap.total_ascent);
  else if ([ident isEqualToString:@"descent"])
    act::format_duration(str, lap.total_descent);
  else if ([ident isEqualToString:@"pace"] && lap.avg_speed != 0)
    act::format_pace(str, lap.avg_speed, act::unit_type::unknown);
  else if ([ident isEqualToString:@"max_pace"] && lap.max_speed != 0)
    act::format_pace(str, lap.max_speed, act::unit_type::unknown);
  else if ([ident isEqualToString:@"speed"] && lap.avg_speed != 0)
    act::format_speed(str, lap.avg_speed, act::unit_type::unknown);
  else if ([ident isEqualToString:@"max_speed"] && lap.max_speed != 0)
    act::format_speed(str, lap.max_speed, act::unit_type::unknown);
  else if ([ident isEqualToString:@"avg_hr"] && lap.avg_heart_rate != 0)
    act::format_heart_rate(str, lap.avg_heart_rate, act::unit_type::beats_per_minute);
  else if ([ident isEqualToString:@"max_hr"] && lap.max_heart_rate != 0)
    act::format_heart_rate(str, lap.max_heart_rate, act::unit_type::beats_per_minute);
  else if ([ident isEqualToString:@"calories"] && lap.total_calories != 0)
    act::format_number(str, lap.total_calories);
  else if ([ident isEqualToString:@"avg_cadence"] && lap.avg_cadence != 0)
    act::format_cadence(str, lap.avg_cadence, act::unit_type::unknown);
  else if ([ident isEqualToString:@"max_cadence"] && lap.max_cadence != 0)
    act::format_cadence(str, lap.max_cadence, act::unit_type::unknown);
  else if ([ident isEqualToString:@"avg_stance_time"] && lap.avg_stance_time != 0)
    act::format_duration(str, lap.avg_stance_time);
  else if ([ident isEqualToString:@"avg_vertical_oscillation"] && lap.avg_vertical_oscillation != 0)
    act::format_distance(str, lap.avg_vertical_oscillation, act::unit_type::millimetres);

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

@implementation ActLapView

- (CGFloat)heightForWidth:(CGFloat)width
{
  return [_controller lapView_heightForWidth:width];
}

- (void)layoutSubviews
{
  [_controller lapView_layoutSubviews];
}

@end
