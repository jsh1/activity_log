/* -*- c-style: gnu -*-

   Copyright (c) 2013 John Harper <jsh@unfactored.org>

   Permission is hereby granted, free of charge, to any person
   obtaining a copy of this software and associated documentation files
   (the "Software"), to deal in the Software without restriction,
   including without limitation the rights to use, copy, modify, merge,
   publish, distribute, sublicense, and/or sell copies of the Software,
   and to permit persons to whom the Software is furnished to do so,
   subject to the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE. */

#import <AppKit/AppKit.h>

#import "PXSourceListDataSource.h"
#import "PXSourceListDelegate.h"

#import "act-database.h"

@class ActSourceListItem, ActViewController;
@class ActFieldEditor, ActSplitView;

extern NSString *const ActActivityListDidChange;
extern NSString *const ActSelectedActivityDidChange;
extern NSString *const ActSelectedLapIndexDidChange;
extern NSString *const ActCurrentTimeWillChange;
extern NSString *const ActCurrentTimeDidChange;
extern NSString *const ActActivityDidChangeField;
extern NSString *const ActActivityDidChangeBody;
extern NSString *const ActSelectedDeviceDidChange;

enum ActWindowMode
{
  ActWindowMode_Nil,
  ActWindowMode_Viewer,
  ActWindowMode_Importer,
  ActWindowMode_Count,
};

@class ActDevice;

@interface ActWindowController : NSWindowController
    <NSSplitViewDelegate, PXSourceListDataSource, PXSourceListDelegate,
    NSPopoverDelegate>
{
  IBOutlet NSSegmentedControl *_listTypeControl;
  IBOutlet NSSegmentedControl *_reloadControl;
  IBOutlet NSSegmentedControl *_addControl;
  IBOutlet NSSegmentedControl *_importControl;
  IBOutlet NSSegmentedControl *_nextPreviousControl;

  IBOutlet ActSplitView *_splitView;

  IBOutlet PXSourceList *_sourceListView;
  IBOutlet NSView *_contentContainer;

  NSMutableArray *_sourceListItems;

  NSMutableArray *_viewControllers;
  NSMutableDictionary *_splitViews;

  ActFieldEditor *_fieldEditor;
  NSUndoManager *_undoManager;

  NSInteger _windowMode;
  CGFloat _windowModeWidths[ActWindowMode_Count];

  std::unique_ptr<act::database> _database;
  BOOL _needsSynchronize;

  std::vector<act::database::item> _activityList;
  act::activity_storage_ref _selectedActivityStorage;
  std::unique_ptr<act::activity> _selectedActivity;
  NSInteger _selectedLapIndex;
  double _currentTime;

  ActDevice *_selectedDevice;

  NSPopover *_activityPopover;
}

@property(nonatomic) NSInteger windowMode;
@property(nonatomic) NSInteger listViewType;

@property(nonatomic, readonly) act::database *database;

- (void)showQueryResults:(const act::database::query &)query;

- (void)synchronize;
- (void)synchronizeIfNeeded;

@property(nonatomic) const std::vector<act::database::item> &activityList;
@property(nonatomic) act::activity_storage_ref selectedActivityStorage;
@property(nonatomic, readonly) act::activity *selectedActivity;
@property(nonatomic) NSInteger selectedLapIndex;
@property(nonatomic) double currentTime;

@property(nonatomic, retain) ActDevice *selectedDevice;

@property(nonatomic, readonly) ActFieldEditor *fieldEditor;
@property(nonatomic, readonly) NSUndoManager *undoManager;

@property(nonatomic) BOOL needsSynchronize;

- (ActViewController *)viewControllerWithClass:(Class)cls;

- (void)addSplitView:(ActSplitView *)view identifier:(NSString *)ident;
- (void)removeSplitView:(ActSplitView *)view identifier:(NSString *)ident;

- (void)saveWindowState;
- (void)applySavedWindowState;

- (void)activity:(const act::activity_storage_ref)storage
    didChangeField:(NSString *)name;
- (void)activityDidChangeBody:(const act::activity_storage_ref)storage;

// these operate on the selected activity

@property(nonatomic, copy) NSString *bodyString;
@property(nonatomic, copy) NSDate *dateField;
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
- (IBAction)importAllActivities:(id)sender;
- (IBAction)editActivity:(id)sender;
- (IBAction)nextActivity:(id)sender;
- (IBAction)previousActivity:(id)sender;
- (IBAction)firstActivity:(id)sender;
- (IBAction)lastActivity:(id)sender;
- (IBAction)nextPreviousActivity:(id)sender;

- (IBAction)setListViewAction:(id)sender;

- (IBAction)toggleActivityPane:(id)sender;

- (void)showPopoverWithActivityStorage:(act::activity_storage_ref)storage
    relativeToRect:(NSRect)r ofView:(NSView *)view
    preferredEdge:(NSRectEdge)edge;
- (void)hidePopover;

@end
