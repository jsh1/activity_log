// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

@interface ActActivityLapView : ActActivitySubview <NSTableViewDataSource>
{
  NSTableHeaderView *_headerView;
  NSTableView *_tableView;
}

@end
