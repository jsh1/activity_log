// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

@interface ActActivityLapView : ActActivitySubview
  <NSTableViewDataSource, NSTableViewDelegate>
{
  NSTableHeaderView *_headerView;
  NSTableView *_tableView;
}

@end
