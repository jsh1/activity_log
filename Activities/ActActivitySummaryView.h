// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

@class ActActivityTextField, ActExpandableTextField;
@class ActHorizontalBoxView, ActActivityHeaderView;

@interface ActActivitySummaryView : ActActivitySubview <NSTextViewDelegate>
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

  IBOutlet ActActivityTextField *_courseField;
  IBOutlet NSTextView *_bodyTextView;
  IBOutlet ActActivityHeaderView *_headerView;

  NSDictionary *_fieldControls;		// FIELD-NAME -> CONTROL
}

+ (NSColor *)textFieldColor:(BOOL)readOnly;

- (IBAction)controlAction:(id)sender;

@end
