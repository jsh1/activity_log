/* -*- c-style: gnu -*-

   Copyright (c) 2014 John Harper <jsh@unfactored.org>

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

#import "ActTableViewStringEditorCell.h"

#import "FoundationExtensions.h"

@implementation ActTableViewStringEditorCell

+ (NSString *)nibName
{
  return @"TableViewStringEditorCell";
}

- (void)invalidate
{
  _textField.delegate = nil;
}

- (void)dealloc
{
  [self invalidate];
}

- (NSString *)stringValue
{
  return _textField.text;
}

- (void)setStringValue:(NSString *)str
{
  _textField.text = str;
}

- (BOOL)becomeFirstResponder
{
  _textField.delegate = self;

  return [_textField becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
  /* FIXME: app crashes the second time I edit a field unless I unset
     the delegate pointer when resigning firstResponder status. */

  _textField.delegate = nil;

  return [_textField resignFirstResponder];
}

/* UITextFieldDelegate methods. */

- (BOOL)textFieldShouldEndEditing:(UITextField *)field
{
  return NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)field
{
  [self sendAction];
  return YES;
}

@end
