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

@class ActWeekListView, ActWeekHeaderView;
@class ActWeekView_ActivityLayer;

enum ActWeekViewDisplayMode
{
  ActWeekView_Distance,
  ActWeekView_Duration,
  ActWeekView_Points,
};

@interface ActWeekViewController : ActViewController
{
  IBOutlet NSScrollView *_scrollView;
  IBOutlet ActWeekListView *_listView;
  IBOutlet ActWeekHeaderView *_headerView;
  IBOutlet NSSegmentedControl *_displayModeControl;
  IBOutlet NSSlider *_scaleSlider;

  CGFloat _interfaceScale;
  int _displayMode;

  int _animationsEnabled;
  int _animationsDisabled;
}

@property(nonatomic) CGFloat interfaceScale;
@property(nonatomic) int displayMode;

- (int)weekForActivityStorage:(const act::activity_storage_ref)storage;

- (IBAction)controlAction:(id)sender;

@end

@interface ActWeekListView : NSView
{
  IBOutlet ActWeekViewController *_controller;

  NSRange _weekRange;

  NSTrackingArea *_trackingArea;
  ActWeekView_ActivityLayer *_expandedLayer;
  ActWeekView_ActivityLayer *_selectedLayer;
}

@property(nonatomic) NSRange weekRange;

- (NSRect)rectForWeek:(int)week;
- (NSRect)visibleRectForWeek:(int)week;

@end

@interface ActWeekHeaderView : NSView
{
  IBOutlet ActWeekViewController *_controller;
}
@end
