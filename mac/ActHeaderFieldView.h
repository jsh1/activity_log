/* -*- c-style: gnu -*-

   Copyright (c) 2013 John Harper <jsh@unfactored.org>

   Permission is hereby granted, free of charge, to any person
   obtaining a copy of this software and associated documentation files
   (the "Software"), to deal in the Software without restriction,
   including without limitation the rights to use, copy, modify, merge,
   publish, distribute, sublicense, and/or sell copies of the Software,
   and to permit persons to whom the Software is furnished to do so,
   subject to the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE. */

#import "ActTextField.h"

@class ActHeaderView;

@interface ActHeaderFieldView : NSView <ActTextFieldDelegate>
{
  ActHeaderView *_headerView;

  ActTextField *_labelField;
  ActTextField *_valueField;

  NSString *_fieldName;

  int _depth;
}

@property(nonatomic, assign) ActHeaderView *headerView;

@property(nonatomic, copy) NSString *fieldName;
@property(nonatomic, copy) NSString *fieldString;

- (void)update;

@property(nonatomic, readonly) CGFloat preferredHeight;

- (void)layoutSubviews;

// controller calls -makeFirstResponder: with these views

@property(nonatomic, readonly) NSView *nameView;
@property(nonatomic, readonly) NSView *valueView;
  
@end
