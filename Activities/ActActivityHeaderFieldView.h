// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

@interface ActActivityHeaderFieldView : ActActivitySubview
{
  IBOutlet NSTextField *_labelView;
  IBOutlet NSTextView *_textView;

  NSString *_fieldName;
}

@property(nonatomic, copy) NSString *fieldName;
@property(nonatomic, copy) NSString *fieldString;
  
@end
