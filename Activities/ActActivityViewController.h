// -*- c-style: gnu -*-

#import "ActViewController.h"

@class ActActivityView;

@interface ActActivityViewController : ActViewController
{
  IBOutlet NSScrollView *_scrollView;
  IBOutlet ActActivityView *_activityView;
}
@end

@interface ActActivityView : NSView
{
  IBOutlet ActActivityViewController *_controller;

  BOOL _needsLayout;
  int _ignoreLayout;
}
@end
