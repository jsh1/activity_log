// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

#import "act-database.h"

@class ActActivityView, ActActivityListView;

@interface ActWindowController : NSWindowController <NSSplitViewDelegate>
{
@private
  IBOutlet ActActivityView *_activityView;
  IBOutlet ActActivityListView *_activityListView;
  IBOutlet NSSplitView *_verticalSplitView;
  IBOutlet NSSplitView *_horizontalSplitView;

  std::unique_ptr<act::database> _database;
}

@property(readonly) act::database *database;

@property act::activity_storage_ref selectedActivity;

@end
