// -*- c-style: gnu -*-

#import "ActViewController.h"

@class ActActivityView;

@interface ActActivityViewController : ActViewController
{
  IBOutlet NSScrollView *_scrollView;
  IBOutlet ActActivityView *_activityView;

  NSMutableArray *_viewControllers;
}
@end

@interface ActActivityView : NSView
{
  IBOutlet ActActivityViewController *_controller;

  int _ignoreLayout;
}
@end
