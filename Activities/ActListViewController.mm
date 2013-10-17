// -*- c-style: gnu -*-

#import "ActListViewController.h"

#import "ActWindowController.h"

#import "act-format.h"

#import <algorithm>

@implementation ActListViewController

+ (NSString *)viewNibName
{
  return @"ActListView";
}

- (void)viewDidLoad
{
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityListDidChange:)
   name:ActActivityListDidChange object:_controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:_controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeField:)
   name:ActActivityDidChangeField object:_controller];

  for (NSTableColumn *col in [_tableView tableColumns])
    [[col dataCell] setVerticallyCentered:YES];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [NSRunLoop cancelPreviousPerformRequestsWithTarget:self];

  [super dealloc];
}

- (NSView *)initialFirstResponder
{
  return _tableView;
}

- (NSInteger)rowForActivityStorage:(const act::activity_storage_ref)storage
{
  if (storage == nullptr)
    return NSNotFound;

  const std::vector<act::activity_storage_ref> &activities
    = [_controller activityList];

  const auto &pos = std::find(activities.begin(), activities.end(), storage);

  if (pos != activities.end())
    return pos - activities.begin();
  else
    return NSNotFound;
}

- (act::activity *)activityForRow:(NSInteger)row
{
  const std::vector<act::activity_storage_ref> vec
    = [_controller activityList];
  act::activity_storage_ref storage = vec[row];

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
		      [_controller selectedActivityStorage]];

  NSIndexSet *set = nil;

  if (newRow != NSNotFound)
    {
      if (newRow != [_tableView selectedRow])
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
  void *ptr = [[[note userInfo] objectForKey:@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);

  NSInteger row = [self rowForActivityStorage:a];
  if (row == NSNotFound)
    return;

  [_tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
   columnIndexes:[NSIndexSet indexSetWithIndexesInRange:
		  NSMakeRange(0, [_tableView numberOfColumns])]];
}

// NSTableViewDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
  const std::vector<act::activity_storage_ref> &activities
    = [_controller activityList];

  return activities.size();
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
  const std::vector<act::activity_storage_ref> &activities
    = [_controller activityList];

  if (row >= 0 && row < activities.size())
    [_controller setSelectedActivityStorage:activities[row]];
  else
    [_controller setSelectedActivityStorage:nullptr];
}

@end
