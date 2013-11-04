// -*- c-style: gnu -*-

#import "ActViewController.h"

@interface ActImporterViewController : ActViewController
    <NSTableViewDataSource, NSTableViewDelegate>
{
  IBOutlet NSTableView *_tableView;
  IBOutlet NSButton *_importButton;

  NSMutableArray *_activities;
}

- (IBAction)importAction:(id)sender;
- (IBAction)revealAction:(id)sender;

@end
