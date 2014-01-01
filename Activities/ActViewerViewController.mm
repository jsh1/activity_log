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

  [_controller addSplitView:_splitView identifier:@"Viewer"];
  [_splitView setIndexOfResizableSubview:1];

  for (ActViewController *controller in [self subviewControllers])
    {
      if ([controller isKindOfClass:[ActActivityViewController class]])
	{
	  [controller addToContainerView:_contentContainer];
	  [[controller view] setHidden:
	   [_controller selectedActivityStorage] ? NO : YES];
	}
      else
	[controller addToContainerView:_listContainer];
    }

  if (_listViewType < 0)
    [self setListViewType:0];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (NSView *)initialFirstResponder
{
  Class cls = (_listViewType == 0
	       ? [ActNotesListViewController class]
	       : [ActListViewController class]);

  return [[self viewControllerWithClass:cls] initialFirstResponder];
}

- (void)setListViewType:(NSInteger)type
{
  if (_listViewType != type)
    {
      NSWindow *window = [[self view] window];

      ActViewController *list = [self viewControllerWithClass:
				 [ActListViewController class]];
      ActViewController *notes = [self viewControllerWithClass:
				  [ActNotesListViewController class]];

      ActViewController *oldC = type == 0 ? list : notes;
      ActViewController *newC = type == 1 ? list : notes;

      NSResponder *first = [window firstResponder];

      BOOL firstResponder = ([first isKindOfClass:[NSView class]]
			     && [(NSView *)first isDescendantOf:[oldC view]]);

      [[newC view] setHidden:NO];
      [[oldC view] setHidden:YES];

      _listViewType = type;

      [window setInitialFirstResponder:[newC initialFirstResponder]];

      if (firstResponder)
	[window makeFirstResponder:[newC initialFirstResponder]];
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

  [state setObject:[NSNumber numberWithUnsignedInt:_listViewType]
   forKey:@"ActSelectedListView"];

  return state;
}

- (void)applySavedViewState:(NSDictionary *)state
{
  [super applySavedViewState:state];

  if (NSNumber *obj = [state objectForKey:@"ActSelectedListView"])
    {
      [self setListViewType:[obj intValue]];
    }
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  ActViewController *activityC = [self viewControllerWithClass:
				  [ActActivityViewController class]];

  [[activityC view] setHidden:
   [_controller selectedActivityStorage] ? NO : YES];
}

@end
