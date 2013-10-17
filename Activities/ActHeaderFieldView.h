// -*- c-style: gnu -*-

#import "ActTextField.h"

@class ActHeaderView;

@interface ActHeaderFieldView : NSView <ActTextFieldDelegate>
{
  ActHeaderView *_headerView;

  ActTextField *_labelField;
  ActTextField *_valueField;

  NSString *_fieldName;
}

@property(nonatomic, assign) ActHeaderView *headerView;

@property(nonatomic, copy) NSString *fieldName;
@property(nonatomic, copy) NSString *fieldString;

- (void)update;

- (CGFloat)preferredHeight;
- (void)layoutSubviews;

// controller calls -makeFirstResponder: with these views

@property(nonatomic, readonly) NSView *nameView;
@property(nonatomic, readonly) NSView *valueView;
  
@end
