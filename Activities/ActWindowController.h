// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

#import "act-database.h"

@class ActViewController;
@class ActListViewController, ActSummaryViewController;
@class ActMapViewController, ActChartViewController;
@class ActFieldEditor, ActSplitView;

extern NSString *const ActActivityListDidChange;
extern NSString *const ActSelectedActivityDidChange;
extern NSString *const ActSelectedLapIndexDidChange;
extern NSString *const ActActivityDidChangeField;
extern NSString *const ActActivityDidChangeBody;

@interface ActWindowController : NSWindowController <NSSplitViewDelegate>
{
  IBOutlet NSButton *_addButton;
  IBOutlet NSButton *_deleteButton;
  IBOutlet NSButton *_reloadButton;
  IBOutlet NSButton *_revealButton;
  IBOutlet NSSegmentedControl *_listViewControl;

  IBOutlet ActSplitView *_outerSplitView;
  IBOutlet ActSplitView *_leftRightSplitView;
  IBOutlet ActSplitView *_leftSplitView;
  IBOutlet ActSplitView *_rightSplitView;

  IBOutlet NSView *_topLeftContainer;		// activity list
  IBOutlet NSView *_bottomLeftContainer;	// activity summary
  IBOutlet NSView *_topRightContainer;		// map view
  IBOutlet NSView *_middleRightContainer;	// lap view
  IBOutlet NSView *_bottomRightContainer;	// chart view

  NSMutableArray *_viewControllers;
  NSMapTable *_splitViews;

  ActFieldEditor *_fieldEditor;
  NSUndoManager *_undoManager;

  std::unique_ptr<act::database> _database;
  BOOL _needsSynchronize;

  std::vector<act::activity_storage_ref> _activityList;
  act::activity_storage_ref _selectedActivityStorage;
  std::unique_ptr<act::activity> _selectedActivity;
  NSInteger _selectedLapIndex;
}

@property(nonatomic, readonly) act::database *database;

@property(nonatomic) const std::vector<act::activity_storage_ref> &activityList;
@property(nonatomic) act::activity_storage_ref selectedActivityStorage;
@property(nonatomic, readonly) act::activity *selectedActivity;
@property(nonatomic) NSInteger selectedLapIndex;

@property(nonatomic, readonly) ActFieldEditor *fieldEditor;
@property(nonatomic, readonly) NSUndoManager *undoManager;

@property(nonatomic) BOOL needsSynchronize;

- (ActViewController *)viewControllerWithClass:(Class)cls;

- (void)addSplitView:(ActSplitView *)view identifier:(NSString *)ident;
- (void)removeSplitView:(ActSplitView *)view;

- (void)saveWindowState;
- (void)applySavedWindowState;

- (void)synchronize;
- (void)synchronizeIfNeeded;

- (void)selectedActivityDidChange;
- (void)selectedLapDidChange;

- (void)activity:(const act::activity_storage_ref)storage
    didChangeField:(NSString *)name;
- (void)activityDidChangeBody:(const act::activity_storage_ref)storage;

// these operate on the selected activity

- (NSString *)bodyString;
- (void)setBodyString:(NSString *)str;
- (NSDate *)dateField;
- (void)setDateField:(NSDate *)date;
- (NSString *)stringForField:(NSString *)name;
- (BOOL)isFieldReadOnly:(NSString *)name;
- (void)setString:(NSString *)str forField:(NSString *)name;
- (void)deleteField:(NSString *)name;
- (void)renameField:(NSString *)oldName to:(NSString *)newName;

// these operate on the specified activity

- (NSString *)bodyStringOfActivity:(const act::activity &)a;
- (void)setBodyString:(NSString *)str ofActivity:(act::activity &)a;
- (NSString *)stringForField:(NSString *)name
    ofActivity:(const act::activity &)a;
- (BOOL)isFieldReadOnly:(NSString *)name ofActivity:(const act::activity &)a;
- (void)setString:(NSString *)str forField:(NSString *)name
    ofActivity:(act::activity &)a;
- (void)deleteField:(NSString *)name ofActivity:(act::activity &)a;
- (void)renameField:(NSString *)oldName to:(NSString *)newName
    ofActivity:(act::activity &)a;

- (IBAction)newActivity:(id)sender;
- (IBAction)importFile:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)reloadDatabase:(id)sender;
- (IBAction)editActivity:(id)sender;
- (IBAction)nextActivity:(id)sender;
- (IBAction)previousActivity:(id)sender;
- (IBAction)firstActivity:(id)sender;
- (IBAction)lastActivity:(id)sender;

- (IBAction)controlAction:(id)sender;

@end
