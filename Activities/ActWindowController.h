// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

#import "act-database.h"

@class ActActivityView, ActActivityListView;

@interface ActWindowController : NSWindowController <NSSplitViewDelegate>
{
  IBOutlet ActActivityView *_activityView;
  IBOutlet ActActivityListView *_activityListView;
  IBOutlet NSSplitView *_verticalSplitView;
  IBOutlet NSSplitView *_horizontalSplitView;

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
