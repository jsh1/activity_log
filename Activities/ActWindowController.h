// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

#import "act-database.h"

@interface ActWindowController : NSWindowController <NSSplitViewDelegate>
{
@private
  IBOutlet NSSplitView *_verticalSplitView;
  IBOutlet NSSplitView *_horizontalSplitView;

  act::database *_database;
}

@property(readonly) act::database *database;

@end
