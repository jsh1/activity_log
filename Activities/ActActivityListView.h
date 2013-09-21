// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

#import "act-activity.h"

#import <vector>

@class ActWindowController;

@interface ActActivityListView : NSView
  <NSTableViewDelegate, NSTableViewDataSource>
{
@private
  IBOutlet ActWindowController *_controller;
  IBOutlet NSTableView *_tableView;

  std::vector<act::activity_storage_ref> _activities;
}

@property const std::vector<act::activity_storage_ref> &activities;

@property act::activity_storage_ref selectedActivity;

- (NSInteger)rowForActivity:(const act::activity_storage_ref)storage;

- (void)reloadActivity:(const act::activity_storage_ref)a;

@end
