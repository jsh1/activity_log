// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

#import "act-database.h"

@class ActActivityViewController, ActActivityListView;

@interface ActWindowController : NSWindowController <NSSplitViewDelegate>
{
  IBOutlet ActActivityListView *_activityListView;
  IBOutlet NSView *_mainContentView;
  IBOutlet NSSplitView *_verticalSplitView;
  IBOutlet NSSplitView *_horizontalSplitView;

  ActActivityViewController *_activityViewController;

  NSUndoManager *_undoManager;

  std::unique_ptr<act::database> _database;
  BOOL _needsSynchronize;
}

@property(nonatomic, readonly) act::database *database;

@property(nonatomic) act::activity_storage_ref selectedActivity;

@property(nonatomic, readonly) NSUndoManager *undoManager;

- (void)reloadSelectedActivity;

@property(nonatomic) BOOL needsSynchronize;

- (void)synchronize;

@end
