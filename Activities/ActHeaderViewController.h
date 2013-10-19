// -*- c-style: gnu -*-

#import "ActViewController.h"
#import "ActTextField.h"

@class ActCollapsibleView, ActHorizontalBoxView, ActHeaderView;

@interface ActHeaderViewController : ActViewController
{
  IBOutlet ActCollapsibleView *_containerView;
  IBOutlet ActHorizontalBoxView *_boxView;
  IBOutlet ActHeaderView *_headerView;
}

@end
