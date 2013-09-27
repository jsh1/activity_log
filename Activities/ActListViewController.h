// -*- c-style: gnu -*-

#import "ActViewController.h"

#import "act-activity.h"

@class ActViewController;

@interface ActListViewController : ActViewController
  <NSTableViewDelegate, NSTableViewDataSource>
{
  IBOutlet NSTableView *_tableView;

  std::vector<act::activity_storage_ref> _activities;
  std::vector<std::unique_ptr<act::activity>> _activity_cache;
}

@property act::activity_storage_ref selectedActivity;

- (NSInteger)rowForActivity:(const act::activity_storage_ref)storage;

@end
