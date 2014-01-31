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

#import "ActActivityViewController.h"

#import "ActActivityEditorViewController.h"
#import "ActActivityChartListViewController.h"
#import "ActActivitySummaryViewController.h"
#import "ActActivityMapViewController.h"
#import "ActAppDelegate.h"
#import "ActColor.h"
#import "ActDatabaseManager.h"
#import "ActFileManager.h"

#import "FoundationExtensions.h"

#import <time.h>
#import <xlocale.h>

@interface ActActivityViewController ()
@property(nonatomic) Class childViewControllerClass;
@property(nonatomic) UIViewController<ActActivityChildViewController> *childViewController;
- (void)reloadData;
- (void)updateToolbar;
@end

@implementation ActActivityViewController

+ (ActActivityViewController *)instantiate
{
  return [[[NSBundle mainBundle] loadNibNamed:
	   @"ActivityView" owner:self options:nil] firstObject];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  ActFileManager *fm = [ActFileManager sharedManager];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(metadataCacheDidChange:)
   name:ActMetadataCacheDidChange object:fm];
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(fileCacheDidChange:)
   name:ActFileCacheDidChange object:fm];

  _editItem = [[UIBarButtonItem alloc]
	       initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
	       target:self action:@selector(editAction:)];

  /* FIXME: need images for these. */

  _summaryItem = [[UIBarButtonItem alloc] initWithTitle:@"Summary"
		  style:UIBarButtonItemStyleBordered target:self
		  action:@selector(showSummaryAction:)];

  _mapItem = [[UIBarButtonItem alloc] initWithTitle:@"Map"
	      style:UIBarButtonItemStyleBordered target:self
	      action:@selector(showMapAction:)];

  _chartsItem = [[UIBarButtonItem alloc] initWithTitle:@"Charts"
		 style:UIBarButtonItemStyleBordered target:self
		 action:@selector(showChartsAction:)];

  _lapsItem = [[UIBarButtonItem alloc] initWithTitle:@"Laps"
	       style:UIBarButtonItemStyleBordered target:self
	       action:@selector(showLapsAction:)];

  self.toolbarItems = @[_summaryItem,
			[[UIBarButtonItem alloc] initWithBarButtonSystemItem:
			 UIBarButtonSystemItemFlexibleSpace target:nil
			 action:nil],
			_mapItem,
			[[UIBarButtonItem alloc] initWithBarButtonSystemItem:
			 UIBarButtonSystemItemFlexibleSpace target:nil
			 action:nil],
			_chartsItem,
			[[UIBarButtonItem alloc] initWithBarButtonSystemItem:
			 UIBarButtonSystemItemFlexibleSpace target:nil
			 action:nil],
			_lapsItem];
}

- (void)viewWillAppear:(BOOL)flag
{
  [super viewWillAppear:flag];

  [self.navigationController setToolbarHidden:NO animated:flag];

  if (_childViewController == nil)
    [self showSummaryAction:_summaryItem];
  else
    [self reloadData];
}

- (void)viewWillDisappear:(BOOL)flag
{
  [super viewWillDisappear:flag];

  UINavigationController *nav = self.navigationController;
  [nav setNavigationBarHidden:NO animated:flag];
  [nav setToolbarHidden:YES animated:flag];
}

namespace {

struct gps_reader : public act::activity::gps_data_reader
{
  __weak ActActivityViewController *_controller;

  gps_reader(ActActivityViewController *controller)
  : _controller(controller) {}

  virtual act::gps::activity *read_gps_file(const act::activity &a) const;
};

} // anonymous namespace

act::gps::activity *
gps_reader::read_gps_file(const act::activity &a) const
{
  if (_controller->_activity.get() != &a)
    return nullptr;

  NSString *path = _controller->_activityGPSPath;
  if (path == nil)
    return nullptr;

  ActFileManager *fm = [ActFileManager sharedManager];
  
  NSDictionary *meta = [fm metadataForRemotePath:
			[path stringByDeletingLastPathComponent]];
  if (meta == nil)
    return nullptr;

  NSString *file = [path lastPathComponent];

  for (NSDictionary *sub in meta[@"contents"])
    {
      NSString *name = sub[@"name"];
      if (![name isEqualToString:file caseInsensitive:YES])
	continue;

      NSString *rev = sub[@"rev"];
      NSString *local_path = [fm localPathForRemotePath:path revision:rev];

      if (local_path != nil)
	{
	  act::gps::activity *gps_data = new act::gps::activity;

	  if (gps_data->read_file([local_path fileSystemRepresentation]))
	    {
	      _controller->_activityGPSRev = rev;
	      return gps_data;
	    }

	  delete gps_data;
	}

      break;
    }

  return nullptr;
}

- (void)metadataCacheDidChange:(NSNotification *)note
{
  NSString *remote_path = [note userInfo][@"remotePath"];

  if ([[_activityGPSPath stringByDeletingLastPathComponent]
       isEqualToString:remote_path caseInsensitive:YES])
    {
      /* FIXME: check revision for our file. */

      _activity->invalidate_gps_data();
      _activityGPSRev = nil;

      [self reloadData];
    }
}

- (void)fileCacheDidChange:(NSNotification *)note
{
  NSString *remote_path = [note userInfo][@"remotePath"];

  if ([_activityGPSPath isEqualToString:remote_path caseInsensitive:YES])
    {
      _activity->invalidate_gps_data();
      _activityGPSRev = nil;

      [self reloadData];
    }
}

- (act::activity_storage_ref)activityStorage
{
  return _activity ? _activity->storage() : nullptr;
}

- (void)setActivityStorage:(act::activity_storage_ref)storage
{
  if (self.activityStorage != storage)
    {
      ActAppDelegate *delegate
	= (id)[UIApplication sharedApplication].delegate;

      _activity.reset(new act::activity(storage));

      _activityGPSPath = nil;
      if (const std::string *str = _activity->field_ptr("gps-file"))
	{
	  time_t date = _activity->date();
	  struct tm tm = {0};
	  localtime_r(&date, &tm);
	  char buf[128];
	  snprintf_l(buf, sizeof(buf), nullptr, "%d/%02d/",
		     tm.tm_year + 1900, tm.tm_mon + 1);

	  std::string tem(buf);
	  tem.append(*str);

	  _activityGPSPath = [delegate remoteGPSPath:
			      [NSString stringWithUTF8String:tem.c_str()]];
	}

      _activityGPSReader.reset(new gps_reader(self));
      _activity->set_gps_data_reader(_activityGPSReader.get());

      _activity->invalidate_gps_data();
      _activityGPSRev = nil;

      [self reloadData];
    }
}

- (act::activity *)activity
{
  return _activity.get();
}

- (BOOL)isFullscreen
{
  return self.navigationController.navigationBarHidden;
}

- (void)setFullscreen:(BOOL)flag
{
  UINavigationController *nav = self.navigationController;
  [nav setNavigationBarHidden:flag animated:YES];
  [nav setToolbarHidden:flag animated:YES];
  [self setNeedsStatusBarAppearanceUpdate];
}

- (BOOL)prefersStatusBarHidden
{
  return self.fullscreen;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
  return UIStatusBarAnimationSlide;
}

- (void)reloadData
{
  if ([_childViewController respondsToSelector:@selector(reloadData)])
    [_childViewController reloadData];
}

- (Class)childViewControllerClass
{
  return [_childViewController class];
}

- (void)setChildViewControllerClass:(Class)cls
{
  if (cls != self.childViewControllerClass)
    {
      self.childViewController = [[cls alloc] init];
    }
}

- (UIViewController<ActActivityChildViewController> *)childViewController
{
  return _childViewController;
}

- (void)setChildViewController:(UIViewController<ActActivityChildViewController> *)controller
{
  if (_childViewController != controller)
    {
      if (_childViewController != nil)
	{
	  [_childViewController.view removeFromSuperview];

	  [_childViewController removeFromParentViewController];
	}

      _childViewController = controller;

      if (_childViewController != nil)
	{
	  [self addChildViewController:_childViewController];

	  UIView *child_view = _childViewController.view;
	  UIView *container_view = self.view;

	  child_view.frame = container_view.bounds;
	  [container_view addSubview:child_view];

	  [self updateViewConstraints];
	}

      self.fullscreen = NO;
      [self updateToolbar];
      [self reloadData];
    }
}

- (void)updateViewConstraints
{
  [super updateViewConstraints];

  if (_childViewController != nil)
    {
      UIEdgeInsets inset = UIEdgeInsetsMake(self.topLayoutGuide.length, 0,
					    self.bottomLayoutGuide.length, 0);

      if ([_childViewController
	   respondsToSelector:@selector(setContentInset:)])
	{
	  [_childViewController setContentInset:inset];
	}
      else
	{
	  UIScrollView *view = (id)_childViewController.view;
	  if ([view isKindOfClass:[UIScrollView class]])
	    view.contentInset = inset;
	}
    }
}

- (void)setBarButtonItem:(UIBarButtonItem *)item selected:(BOOL)flag 
{
  if (_itemBgImageSelected == nil)
    {
      UIGraphicsBeginImageContextWithOptions(CGSizeMake(8, 8), NO,
					     [UIScreen mainScreen].scale);

      /* Creating an empty image to avoid changing the button metrics
	 when installing the selected button background. */

      _itemBgImageNormal = UIGraphicsGetImageFromCurrentImageContext();

      [[[ActColor tintColor] colorWithAlphaComponent:.12] setFill];
      [[UIBezierPath bezierPathWithRoundedRect:
	CGRectMake(0, 0, 8, 8) cornerRadius:3.5] fill];

      if (UIImage *im = UIGraphicsGetImageFromCurrentImageContext())
	{
	  _itemBgImageSelected = [im resizableImageWithCapInsets:
				  UIEdgeInsetsMake(4, 4, 4, 4)
				  resizingMode:UIImageResizingModeStretch];
	}

      UIGraphicsEndImageContext();
    }

  UIImage *im = flag ? _itemBgImageSelected : _itemBgImageNormal;
  [item setBackgroundImage:im forState:UIControlStateNormal
   barMetrics:UIBarMetricsDefault];
}

- (void)updateToolbar
{
  Class cls = [_childViewController class];

  NSArray *right_items = nil;
  if ([_childViewController respondsToSelector:@selector(rightBarButtonItems)])
    right_items = [_childViewController rightBarButtonItems];

  if (right_items == nil)
    right_items = @[_editItem];

  [self.navigationItem setRightBarButtonItems:right_items animated:YES];

  [self setBarButtonItem:_summaryItem
   selected:cls == [ActActivitySummaryViewController class]];

  [self setBarButtonItem:_mapItem
   selected:cls == [ActActivityMapViewController class]];

  [self setBarButtonItem:_chartsItem
   selected:cls == [ActActivityChartListViewController class]];

  _lapsItem.enabled = NO;
}

- (IBAction)showSummaryAction:(id)sender
{
  self.childViewControllerClass = [ActActivitySummaryViewController class];
}

- (IBAction)showLapsAction:(id)sender
{
}

- (IBAction)showMapAction:(id)sender
{
  self.childViewControllerClass = [ActActivityMapViewController class];
}

- (IBAction)showChartsAction:(id)sender
{
  self.childViewControllerClass = [ActActivityChartListViewController class];
}

- (IBAction)editAction:(id)sender
{
  ActActivityEditorViewController *controller
    = [ActActivityEditorViewController instantiate];

  controller.activityStorage = _activity->storage();

  UINavigationController *inner_nav
    = [[UINavigationController alloc] initWithRootViewController:controller];

  inner_nav.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

  [self presentViewController:inner_nav animated:YES completion:nil];
}

@end
