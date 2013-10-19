// -*- c-style: gnu -*-

#import "ActViewController.h"

@class ActLapView;

@interface ActLapViewController : ActViewController
  <NSTableViewDataSource, NSTableViewDelegate>
{
  IBOutlet ActLapView *_lapView;
  NSTableView *_tableView;
  NSTableHeaderView *_headerView;
}

@end

@interface ActLapView : NSView
{
  IBOutlet ActLapViewController *_controller;
}
@end
