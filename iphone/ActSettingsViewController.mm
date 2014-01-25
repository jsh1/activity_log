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

#import "ActSettingsViewController.h"

#import "ActAppDelegate.h"

@implementation ActSettingsViewController

+ (ActSettingsViewController *)instantiate
{
  UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Settings" bundle:nil];
  return [sb instantiateViewControllerWithIdentifier:@"tableViewController"];
}

- (NSString *)title
{
  return @"Settings";
}

- (void)viewDidLoad
{
}

- (void)viewWillAppear:(BOOL)animated
{
  ActAppDelegate *delegate = (id)[UIApplication sharedApplication].delegate;

  _linkedSwitch.on = delegate.dropboxLinked;
}

- (IBAction)linkAction:(id)sender
{
  ActAppDelegate *delegate = (id)[UIApplication sharedApplication].delegate;

  delegate.dropboxLinked = _linkedSwitch.on;
  _linkedSwitch.on = delegate.dropboxLinked;
}

- (IBAction)doneAction:(id)sender
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

/* UITextFieldDelegate methods. */

- (void)textFieldDidBeginEditing:(UITextField *)field
{
}

- (BOOL)textFieldShouldClear:(UITextField *)field
{
  return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)field
{
  [field resignFirstResponder];
  return YES;
}

@end
