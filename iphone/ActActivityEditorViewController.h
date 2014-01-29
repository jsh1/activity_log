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

#import <UIKit/UIKit.h>

#import "act-activity.h"

@class ActFieldEditorViewController;

@interface ActActivityEditorViewController : UITableViewController
    <UITableViewDataSource, UITableViewDelegate>
{
  act::activity_storage_ref _activityStorage;

  /* Has a copy of _activityStorage, not the original. */

  std::unique_ptr<act::activity> _activity;
  BOOL _activityModified;
}

+ (ActActivityEditorViewController *)instantiate;

/* Setter copies the passed in object. */

@property(nonatomic) act::activity_storage_ref activityStorage;

- (IBAction)doneAction:(id)sender;
- (IBAction)cancelAction:(id)sender;

@end
