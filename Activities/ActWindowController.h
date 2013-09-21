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

@property(nonatomic) BOOL needsSynchronize;

- (void)synchronize;

- (void)activity:(const act::activity_storage_ref)storage
    didChangeField:(NSString *)name;
- (void)activityDidChangeBody:(const act::activity_storage_ref)storage;

- (NSString *)stringForField:(NSString *)name
    ofActivity:(const act::activity &)a;
- (BOOL)isFieldReadOnly:(NSString *)name ofActivity:(const act::activity &)a;
- (void)setString:(NSString *)str forField:(NSString *)name
    ofActivity:(act::activity &)a;
- (void)renameField:(NSString *)oldName to:(NSString *)newName
    ofActivity:(act::activity &)a;

- (NSString *)bodyStringOfActivity:(const act::activity &)a;
- (void)setBodyString:(NSString *)str ofActivity:(act::activity &)a;

@end
