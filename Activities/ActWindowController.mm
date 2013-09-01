// -*- c-style: gnu -*-

#import "ActWindowController.h"

#import "ActActivityListView.h"
#import "ActActivityView.h"

@implementation ActWindowController

- (NSString *)windowNibName
{
  return @"ActWindow";
}

- (id)init
{
  return [super initWithWindow:nil];
}

- (act::database *)database
{
  if (!_database)
    _database.reset (new act::database());

  return _database.get();
}

- (act::activity_storage_ref)selectedActivity
{
  return [_activityView activityStorage];
}

- (void)setSelectedActivity:(act::activity_storage_ref)a
{
  [_activityView setActivityStorage:a];
  [_activityListView setSelectedActivity:a];
}

- (void)reloadSelectedActivity
{
  [_activityListView reloadSelectedActivity];
}

- (void)windowDidLoad
{
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(windowWillClose:)
   name:NSWindowWillCloseNotification object:[self window]];

  // FIXME: only while bootstrapping

  act::database::query query;
  query.add_date_range(act::date_range(0, time(nullptr)));

  std::vector<act::database::item *> items;
  [self database]->execute_query(query, items);

  std::vector<act::activity_storage_ref> activities;

  for (auto &it : items)
    activities.push_back(it->storage());

  [_activityListView setActivities:activities];
}

- (void)windowWillClose:(NSNotification *)note
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [NSApp terminate:self];
}

@end
