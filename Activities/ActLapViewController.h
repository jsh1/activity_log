// -*- c-style: gnu -*-

#import "ActViewController.h"

@interface ActLapViewController : ActViewController
  <NSTableViewDataSource, NSTableViewDelegate>
{
  IBOutlet NSTableView *_tableView;
}

@end
