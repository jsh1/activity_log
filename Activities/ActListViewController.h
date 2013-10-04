// -*- c-style: gnu -*-

#import "ActViewController.h"

#import "act-activity.h"

#import <unordered_map>

@class ActViewController;

@interface ActListViewController : ActViewController
  <NSTableViewDelegate, NSTableViewDataSource>
{
  IBOutlet NSTableView *_tableView;

  std::unordered_map<act::activity_storage_ref,
    std::unique_ptr<act::activity>> _activity_cache;
}

- (NSInteger)rowForActivityStorage:(const act::activity_storage_ref)storage;

@end
