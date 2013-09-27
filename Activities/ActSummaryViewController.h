// -*- c-style: gnu -*-

#import "ActViewController.h"
#import "ActTextField.h"

@class ActHorizontalBoxView, ActHeaderView, ActSplitView;

@interface ActSummaryViewController : ActViewController
    <NSTextViewDelegate, ActTextFieldDelegate>
{
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
  IBOutlet ActSplitView *_splitView;
  IBOutlet NSTextView *_bodyTextView;
  IBOutlet ActHeaderView *_headerView;

  NSDictionary *_fieldControls;		// FIELD-NAME -> CONTROL
}

+ (NSColor *)textFieldColor:(BOOL)readOnly;

- (IBAction)controlAction:(id)sender;

@end

// draws the background rounded rect

@interface ActSummaryView : NSView
{
  IBOutlet ActSummaryViewController *_controller;
}
@end
