// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

@class ActActivityHeaderFieldTextView;

@interface ActActivityHeaderFieldView : ActActivitySubview <NSTextViewDelegate>
{
  NSTextView *_labelView;
  ActActivityHeaderFieldTextView *_textView;

  NSString *_fieldName;
  BOOL _fieldReadOnly;
}

@property(nonatomic, copy) NSString *fieldName;
@property(nonatomic, copy) NSString *fieldString;
@property(nonatomic, readonly, getter=isFieldReadOnly) BOOL fieldReadOnly;
  
@end
