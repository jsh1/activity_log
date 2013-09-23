// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

@class ActActivityTextField, ActActivityHeaderView;

@interface ActActivityHeaderFieldView : ActActivitySubview
    <NSTextFieldDelegate>
{
  ActActivityHeaderView *_headerView;

  ActActivityTextField *_labelField;
  ActActivityTextField *_valueField;

  NSString *_fieldName;
}

+ (NSColor *)textFieldColor:(BOOL)readOnly;

@property(nonatomic, assign) ActActivityHeaderView *headerView;

@property(nonatomic, copy) NSString *fieldName;
@property(nonatomic, copy) NSString *fieldString;

- (CGFloat)preferredHeight;
- (void)layoutSubviews;

// controller calls -makeFirstResponder: with these views

@property(nonatomic, readonly) NSView *nameView;
@property(nonatomic, readonly) NSView *valueView;
  
@end
