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

#import <UIKit/UIKit.h>

#import "act-activity.h"

@protocol ActActivityChildViewController <NSObject>

- (id)init;

@optional

/* Called when activity may have changed. */

- (void)reloadData;

/* If not defined and root view is UIScrollView, will set view's
   contentInset directly. */

- (void)setContentInset:(UIEdgeInsets)inset;

- (UIView *)titleView;
- (NSArray *)rightBarButtonItems;

@end

@interface ActActivityViewController : UIViewController
{
  UIViewController<ActActivityChildViewController> *_childViewController;

  UIBarButtonItem *_editItem;

  UIBarButtonItem *_summaryItem;
  UIBarButtonItem *_mapItem;
  UIBarButtonItem *_chartsItem;
  UIBarButtonItem *_lapsItem;

  UIImage *_itemBgImageNormal;
  UIImage *_itemBgImageSelected;

  std::unique_ptr<act::activity> _activity;
  NSString *_activityGPSPath;
  NSString *_activityGPSRev;
  std::unique_ptr<act::activity::gps_data_reader> _activityGPSReader;
}

+ (ActActivityViewController *)instantiate;

@property(nonatomic) act::activity_storage_ref activityStorage;

@property(nonatomic, readonly) act::activity *activity;

@property(nonatomic, getter=isFullscreen) BOOL fullscreen;

- (IBAction)editAction:(id)sender;

- (IBAction)showSummaryAction:(id)sender;
- (IBAction)showLapsAction:(id)sender;
- (IBAction)showMapAction:(id)sender;
- (IBAction)showChartsAction:(id)sender;

@end
