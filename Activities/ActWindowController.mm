// -*- c-style: gnu -*-

#import "ActWindowController.h"

#import "ActActivityListView.h"
#import "ActActivityViewController.h"

@implementation ActWindowController

@synthesize undoManager = _undoManager;

- (NSString *)windowNibName
{
  return @"ActWindow";
}

- (id)init
{
  self = [super initWithWindow:nil];
  if (self == nil)
    return nil;

  _activityViewController = [[ActActivityViewController alloc] init];

  _undoManager = [[NSUndoManager alloc] init];

  return self;
}

- (void)dealloc
{
  [_activityViewController release];
  [_undoManager release];

  [super dealloc];
}

- (act::database *)database
{
  if (!_database)
    _database.reset (new act::database());

  return _database.get();
}

- (act::activity_storage_ref)selectedActivity
{
  return [_activityListView selectedActivity];
}

- (void)setSelectedActivity:(act::activity_storage_ref)a
{
  [_activityListView setSelectedActivity:a];

  if (a == nullptr)
    [[_activityViewController view] setHidden:YES];

  [_activityViewController setActivityStorage:a];

  if (a != nullptr)
    [[_activityViewController view] setHidden:NO];
}

- (void)reloadSelectedActivity
{
  [_activityListView reloadSelectedActivity];
}

- (void)setNeedsSynchronize:(BOOL)flag
{
  if (flag && !_needsSynchronize)
    {
      _needsSynchronize = YES;

      dispatch_time_t t = dispatch_time(DISPATCH_TIME_NOW, 2LL * NSEC_PER_SEC);
      dispatch_after(t, dispatch_get_main_queue(), ^{
	if (_needsSynchronize)
	  [self synchronize];
      });
    }
}

- (BOOL)needsSynchronize
{
  return _needsSynchronize;
}

- (void)synchronize
{
  _needsSynchronize = NO;

  if (_database)
    _database->synchronize();
}

- (void)windowDidLoad
{
  if (NSView *view = [_activityViewController view])
    {
      [view setFrame:[_mainContentView bounds]];
      [view setHidden:YES];
      [_mainContentView addSubview:view];
    }

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
  if (activities.size() != 0)
    [self setSelectedActivity:activities[0]];
}

- (void)windowWillClose:(NSNotification *)note
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [NSApp terminate:self];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
  return _undoManager;
}

@end
