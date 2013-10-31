// -*- c-style: gnu -*-

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

- (id)initWithController:(ActWindowController *)controller
{
  self = [super initWithController:controller];
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
  addTableColumn(_tableView, font, @"max-pace", @"Max Pace");
  addTableColumn(_tableView, font, @"average-hr", @"Avg HR");
  addTableColumn(_tableView, font, @"max-hr", @"Max HR");
  addTableColumn(_tableView, font, @"calories", @"Calories");

  [_lapView addSubview:_tableView];
  [_tableView release];

  [_headerView setTableView:_tableView];
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
  else if ([ident isEqualToString:@"calories"] && lap.total_calories != 0)
    act::format_number(str, lap.total_calories);

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
