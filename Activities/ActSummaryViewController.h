// -*- c-style: gnu -*-

#import "ActViewController.h"
#import "ActTextField.h"

@class ActSummaryView, ActHorizontalBoxView, ActSplitView;

@interface ActSummaryViewController : ActViewController <NSTextViewDelegate>
{
  IBOutlet ActSummaryView *_summaryView;

  IBOutlet ActHorizontalBoxView *_dateBox;
  IBOutlet ActExpandableTextField *_dateTimeField;
  IBOutlet ActExpandableTextField *_dateDayField;
  IBOutlet ActExpandableTextField *_dateDateField;

  IBOutlet ActHorizontalBoxView *_typeBox;
  IBOutlet ActExpandableTextField *_typeActivityField;
  IBOutlet ActExpandableTextField *_typeTypeField;

  IBOutlet ActHorizontalBoxView *_statsBox;
  IBOutlet ActExpandableTextField *_statsDistanceField;
  IBOutlet ActExpandableTextField *_statsDurationField;
  IBOutlet ActExpandableTextField *_statsPaceField;

  IBOutlet ActTextField *_courseField;

  NSTextView *_bodyTextView;
  NSLayoutManager *_bodyLayoutManager;
  NSTextContainer *_bodyLayoutContainer;

  NSDictionary *_fieldControls;		// FIELD-NAME -> CONTROL

  int _ignoreChanges;
}

- (IBAction)controlAction:(id)sender;

@end

// draws the background rounded rect

@interface ActSummaryView : NSView
{
  IBOutlet ActSummaryViewController *_controller;
}
@end
