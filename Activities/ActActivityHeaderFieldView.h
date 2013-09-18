// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

@class ActActivityHeaderFieldTextView;

@interface ActActivityHeaderFieldView : ActActivitySubview <NSTextViewDelegate>
{
  NSTextView *_labelView;
  ActActivityHeaderFieldTextView *_textView;

  NSString *_fieldName;
}

@property(nonatomic, copy) NSString *fieldName;
@property(nonatomic, copy) NSString *fieldString;

- (CGFloat)preferredHeightForWidth:(CGFloat)width;

- (void)layoutSubviews;
  
@end
