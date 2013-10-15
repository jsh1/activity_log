// -*- c-style: gnu -*-

#import "ActViewController.h"

@class ActSplitView;

@interface ActActivityViewController : ActViewController
{
  IBOutlet ActSplitView *_mainSplitView;
  IBOutlet ActSplitView *_topSplitView;
  IBOutlet ActSplitView *_middleSplitView;

  IBOutlet NSView *_topLeftContainer;		// summary
  IBOutlet NSView *_topRightContainer;		// header fields
  IBOutlet NSView *_middleLeftContainer;	// map
  IBOutlet NSView *_middleRightContainer;	// laps
  IBOutlet NSView *_bottomContainer;		// charts

  NSMutableArray *_viewControllers;
}

@end
