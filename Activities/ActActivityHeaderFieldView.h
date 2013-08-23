// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

@class ActActivityHeaderFieldTextView;

@interface ActActivityHeaderFieldView : ActActivitySubview
{
  NSTextView *_labelView;
  ActActivityHeaderFieldTextView *_textView;

  NSString *_fieldName;
}

@property(nonatomic, copy) NSString *fieldName;
@property(nonatomic, copy) NSString *fieldString;
  
@end
