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

#import "ActViewController.h"
#import "ActTextField.h"

@class ActSummaryView, ActHorizontalBoxView, ActSplitView;

@interface ActSummaryViewController : ActViewController <NSTextViewDelegate>

@property(nonatomic, strong) ActSummaryView *summaryView;

@property(nonatomic, strong) ActHorizontalBoxView *dateBox;
@property(nonatomic, strong) ActExpandableTextField *dateTimeField;
@property(nonatomic, strong) ActExpandableTextField *dateDayField;
@property(nonatomic, strong) ActExpandableTextField *dateDateField;

@property(nonatomic, strong) ActHorizontalBoxView *typeBox;
@property(nonatomic, strong) ActExpandableTextField *typeActivityField;
@property(nonatomic, strong) ActExpandableTextField *typeTypeField;

@property(nonatomic, strong) ActHorizontalBoxView *statsBox;
@property(nonatomic, strong) ActExpandableTextField *statsDistanceField;
@property(nonatomic, strong) ActExpandableTextField *statsDurationField;
@property(nonatomic, strong) ActExpandableTextField *statsPaceField;

@property(nonatomic, strong) ActTextField *courseField;

- (IBAction)controlAction:(id)sender;

@end

// draws the background rounded rect

@interface ActSummaryView : NSView

@property(nonatomic, weak) ActSummaryViewController *controller;

@end
