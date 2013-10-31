// -*- c-style: gnu -*-

#import "ActViewController.h"

@class ActSplitView;

@interface ActViewerViewController : ActViewController
{
  IBOutlet ActSplitView *_splitView;

  IBOutlet NSView *_listContainer;		// activity list
  IBOutlet NSView *_contentContainer;		// activity / summary

  NSInteger _listViewType;
}

@property(nonatomic) NSInteger listViewType;

@end
