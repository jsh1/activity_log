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

#import "ActViewerViewController.h"

#import "ActActivityViewController.h"
#import "ActListViewController.h"
#import "ActNotesListViewController.h"
#import "ActSplitView.h"
#import "ActWeekViewController.h"
#import "ActWindowController.h"

@implementation ActViewerViewController

+ (NSString *)viewNibName
{
  return @"ActViewerView";
}

- (id)initWithController:(ActWindowController *)controller
    options:(NSDictionary *)opts
{
  self = [super initWithController:controller options:opts];
  if (self == nil)
    return nil;

  if (ActViewController *obj = [[ActListViewController alloc]
				initWithController:_controller options:nil])
    {
      [self addSubviewController:obj];
    }

  if (ActViewController *obj = [[ActNotesListViewController alloc]
				initWithController:_controller options:nil])
    {
      [self addSubviewController:obj];
    }

  if (ActViewController *obj = [[ActWeekViewController alloc]
				initWithController:_controller options:nil])
    {
      [self addSubviewController:obj];
    }

  // FIXME: also some kind of multi-activity summary view

  if (ActViewController *obj = [[ActActivityViewController alloc]
				initWithController:_controller options:nil])
    {
      [self addSubviewController:obj];
      [obj release];
    }

  _listViewType = -1;

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:_controller];

  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [_controller addSplitView:_splitView identifier:@"1.Viewer"];
  _splitView.indexOfResizableSubview = 1;

  for (ActViewController *controller in self.subviewControllers)
    {
      if ([controller isKindOfClass:[ActActivityViewController class]])
	{
	  [controller addToContainerView:_contentContainer];
	  controller.view.hidden = _controller.selectedActivityStorage == nullptr;
	}
    }

  if (_listViewType < 0)
    self.listViewType = 0;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_controller removeSplitView:_splitView identifier:@"1.Viewer"];
  [super dealloc];
}

static Class
listViewControllerClass(int type)
{
  if (type == 0)
    return [ActNotesListViewController class];
  else if (type == 1)
    return [ActWeekViewController class];
  else if (type == 2)
    return [ActListViewController class];
  else
    return nil;
}

- (NSView *)initialFirstResponder
{
  Class cls = listViewControllerClass(_listViewType);

  return [self viewControllerWithClass:cls].initialFirstResponder;
}

- (void)setListViewType:(NSInteger)type
{
  if (_listViewType != type)
    {
      NSWindow *window = self.view.window;

      ActViewController *old_cls = listViewControllerClass(_listViewType);
      ActViewController *new_cls = listViewControllerClass(type);

      ActViewController *oldC = [self viewControllerWithClass:old_cls];
      ActViewController *newC = [self viewControllerWithClass:new_cls];

      NSResponder *first = window.firstResponder;

      BOOL firstResponder = ([first isKindOfClass:[NSView class]]
			     && [(NSView *)first isDescendantOf:oldC.view]);

      [newC addToContainerView:_listContainer];
      [oldC removeFromContainer];

      _listViewType = type;

      window.initialFirstResponder = newC.initialFirstResponder;

      if (firstResponder)
	[window makeFirstResponder:newC.initialFirstResponder];
    }
}

- (NSInteger)listViewType
{
  return _listViewType;
}

- (NSDictionary *)savedViewState
{
  NSMutableDictionary *state
    = [NSMutableDictionary dictionaryWithDictionary:[super savedViewState]];

  state[@"ActSelectedListView"] = @(_listViewType);

  return state;
}

- (void)applySavedViewState:(NSDictionary *)state
{
  [super applySavedViewState:state];

  if (NSNumber *obj = state[@"ActSelectedListView"])
    {
      self.listViewType = obj.intValue;
    }
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  ActViewController *activityC = [self viewControllerWithClass:
				  [ActActivityViewController class]];

  activityC.view.hidden = _controller.selectedActivityStorage == nullptr;
}

@end
