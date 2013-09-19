// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

@interface ActActivityLapView : ActActivitySubview
  <NSTableViewDataSource, NSTableViewDelegate>
{
  IBOutlet NSTableView *_tableView;
}

@end
