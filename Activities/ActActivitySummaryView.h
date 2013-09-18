// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

@class ActExpandableTextField, ActHorizontalBoxView;

@interface ActActivitySummaryView : ActActivitySubview <NSTextViewDelegate>
{
  IBOutlet ActExpandableTextField *_dateTextField;
  IBOutlet ActHorizontalBoxView *_activityTypeBoxView;
  IBOutlet ActExpandableTextField *_activityTextField;
  IBOutlet ActExpandableTextField *_typeTextField;
  IBOutlet ActExpandableTextField *_courseTextField;
  IBOutlet NSTextView *_bodyTextView;
}

- (IBAction)controlAction:(id)sender;

@end
