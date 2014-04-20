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

#import "ActTextEditorViewController.h"

#import "ActAppDelegate.h"

@implementation ActTextEditorViewController
{
  NSString *_stringValue;

  CGFloat _currentKeyboardInset;
}

@synthesize stringValue = _stringValue;

- (id)init
{
  return [super initWithNibName:nil bundle:nil];
}

- (UITextView *)textView
{
  return (UITextView *)self.view;
}

- (void)invalidate
{
  self.textView.delegate = nil;

  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc
{
  [self invalidate];
}

- (void)loadView
{
  UITextView *text_view = [[UITextView alloc] initWithFrame:CGRectZero];

  text_view.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
  text_view.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;

  self.view = text_view;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  UIWindow *window = self.view.window;

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(keyboardDidShow:)
   name:UIKeyboardDidShowNotification object:window];
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(keyboardDidHide:)
   name:UIKeyboardDidHideNotification object:window];
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(keyboardDidChangeFrame:)
   name:UIKeyboardDidChangeFrameNotification object:window];

  self.textView.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
  self.textView.text = _stringValue;
}

- (void)viewDidAppear:(BOOL)animated
{
  [self.textView becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated
{
  _stringValue = self.textView.text;

  [self.textView resignFirstResponder];
}

- (void)keyboardDidShow:(NSNotification *)note
{
  UITextView *text_view = self.textView;

  CGRect keyR = [text_view.window convertRect:
		 [[note userInfo][UIKeyboardFrameEndUserInfoKey] CGRectValue]
		 fromView:nil];

  UIEdgeInsets inset = text_view.contentInset;

  inset.bottom -= _currentKeyboardInset;
  _currentKeyboardInset = keyR.size.height;
  inset.bottom += _currentKeyboardInset;

  text_view.contentInset = inset;

  /* FIXME: animated:YES does nothing. Ah the fragility..! */

  [text_view scrollRectToVisible:
   [text_view caretRectForPosition:text_view.selectedTextRange.end]
   animated:NO];
}

- (void)keyboardDidHide:(NSNotification *)note
{
  if (_currentKeyboardInset != 0)
    {
      UIEdgeInsets inset = self.textView.contentInset;

      inset.bottom -= _currentKeyboardInset;
      _currentKeyboardInset = 0;

      self.textView.contentInset = inset;
    }
}

- (void)keyboardDidChangeFrame:(NSNotification *)note
{
  [self keyboardDidShow:note];
}

/* UITextViewDelegate methods. */

- (void)textViewDidChange:(UITextView *)view
{
  CGRect caretR = [view caretRectForPosition:view.selectedTextRange.start];
  CGRect visR = UIEdgeInsetsInsetRect(view.bounds, view.contentInset);

  if (!CGRectContainsRect(visR, caretR))
    {                                    
      /* Normal scroll animation is too slow, so override with our own
	 parameters. */

      [UIView animateWithDuration:.25 delay:0
       options:UIViewAnimationCurveEaseInOut animations:^
	 {
	   [view scrollRectToVisible:caretR animated:NO];
	 } completion:nil];
    }
}

- (void)textViewDidEndEditing:(UITextView *)view
{
  _stringValue = view.text;
}

@end
