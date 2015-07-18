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

#import "ActCollapsibleView.h"
#import "ActViewLayout.h"
#import "ActWindowController.h"

#define MARGIN 10

@implementation ActActivityViewController

+ (NSString *)viewNibName
{
  return @"ActActivityView";
}

- (id)initWithController:(ActWindowController *)controller
    options:(NSDictionary *)opts
{
  self = [super initWithController:controller options:opts];
  if (self == nil)
    return nil;

  NSArray *subviews = [[NSUserDefaults standardUserDefaults]
		       arrayForKey:@"ActActivitySubviewControllers"];

  for (NSDictionary *dict in subviews)
    {
      ActViewController *obj
        = [ActViewController viewControllerWithPropertyListRepresentation:dict
	   controller:_controller];

      if (obj != nil)
	[self addSubviewController:obj];
    }

  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  for (ActViewController *controller in self.subviewControllers)
    [_activityView addSubview:controller.view];
}

- (void)updateSubviews
{
  NSMutableArray *array = [NSMutableArray array];

  for (ActViewController *controller in self.subviewControllers)
    [array addObject:controller.view];

  _activityView.subviews = array;
  [_activityView subviewNeedsLayout:nil];
}

- (void)updateSubviewDefaults
{
  NSMutableArray *array = [NSMutableArray array];

  for (ActViewController *controller in self.subviewControllers)
    {
      id obj = [controller propertyListRepresentation];
      if (obj != nil)
	[array addObject:obj];
    }

  [[NSUserDefaults standardUserDefaults]
   setObject:array forKey:@"ActActivitySubviewControllers"];
}

- (void)addSubviewControllerWithClass:(Class)cls
    after:(ActViewController *)pred
{
  NSString *suffix = nil;

  while (1)
    {
      suffix = [NSString stringWithFormat:@".%08x", arc4random()];
      BOOL unique = YES;
      for (ActViewController *c in self.subviewControllers)
	{
	  if ([c.identifierSuffix isEqualToString:suffix])
	    unique = NO;
	}
      if (unique)
	break;
    }

  NSDictionary *dict = @{
    @"className": NSStringFromClass(cls),
    @"identifierSuffix": suffix
  };

  ActViewController *obj
    = [ActViewController viewControllerWithPropertyListRepresentation:dict
       controller:_controller];

  if (obj != nil)
    [self addSubviewController:obj after:pred];

  [self updateSubviews];
  [self updateSubviewDefaults];
}

- (void)removeSubviewController:(ActViewController *)controller
{
  [super removeSubviewController:controller];

  [self updateSubviews];
  [self updateSubviewDefaults];
}

- (IBAction)toggleActivityPane:(NSControl *)sender
{
  NSString *class_name = nil;

  switch (sender.tag)
    {
    case 1:
      class_name = @"ActSummaryViewController";
      break;
    case 2:
      class_name = @"ActLapViewController";
      break;
    case 3:
      class_name = @"ActHeaderViewController";
      break;
    case 4:
      class_name = @"ActMapViewController";
      break;
    case 5:
      class_name = @"ActChartViewController";
      break;
    default:
      return;
    }

  Class cls = NSClassFromString(class_name);
  if (cls == nil)
    return;

  BOOL any_visible = NO;

  for (ActViewController *controller in self.subviewControllers)
    {
      if ([controller isKindOfClass:cls])
	{
	  ActCollapsibleView *view = (id)controller.view;
	  if ([view isKindOfClass:[ActCollapsibleView class]]
	      && !view.collapsed)
	    any_visible = YES;
	}
    }

  for (ActViewController *controller in self.subviewControllers)
    {
      if ([controller isKindOfClass:cls])
	{
	  ActCollapsibleView *view = (id)controller.view;
	  if ([view isKindOfClass:[ActCollapsibleView class]])
	    view.collapsed = any_visible;
	}
    }
}

- (NSDictionary *)savedViewState
{
  NSMutableDictionary *state
    = [NSMutableDictionary dictionaryWithDictionary:[super savedViewState]];

  NSMutableDictionary *collapsed = [NSMutableDictionary dictionary];

  for (ActViewController *controller in self.subviewControllers)
    {
      ActCollapsibleView *view = (id)controller.view;
      if ([view isKindOfClass:[ActCollapsibleView class]]
	  && view.collapsed)
	collapsed[controller.identifier] = @YES;
    }

  state[@"ActViewCollapsed"] = collapsed;

  return state;
}

- (void)applySavedViewState:(NSDictionary *)state
{
  [super applySavedViewState:state];

  if (NSDictionary *dict = state[@"ActViewCollapsed"])
    {
      for (ActViewController *controller in self.subviewControllers)
	{
	  if (NSNumber *obj = dict[controller.identifier])
	    ((ActCollapsibleView *)controller.view).collapsed = obj.boolValue;
	}
    }
}

@end

@implementation ActActivityView

static CGFloat
layoutSubviews(ActActivityView *self, CGFloat width,
	       BOOL modifySubviews, BOOL updateHeight)
{
  NSRect bounds = self.bounds;
  CGFloat y = 0;

  if (width < 0)
    width = bounds.size.width - MARGIN*2;

  self->_ignoreLayout++;

  for (NSView *view in self.subviews)
    {
      CGFloat height = [view heightForWidth:width];

      if (y == 0)
	y += MARGIN;

      if (modifySubviews)
	{
	  NSRect frame;
	  frame.origin.x = bounds.origin.x + MARGIN;
	  frame.origin.y = bounds.origin.y + y;
	  frame.size.width = width;
	  frame.size.height = height;

	  if (!NSEqualRects(frame, view.frame))
	    view.frame = frame;

	  [view layoutSubviews];
	}

      y += height + MARGIN;
    }

  if (updateHeight && bounds.size.height != y)
    {
      bounds.size.height = y;
      [self setFrameSize:bounds.size];
    }

  self->_ignoreLayout--;

  return y;
}

- (CGFloat)heightForWidth:(CGFloat)width
{
  return layoutSubviews(self, width, NO, NO);
}

- (void)subviewNeedsLayout:(NSView *)view
{
  // This view returns YES from -wantsUpdateLayer, so marking it for
  // redisplay will actually cause -updateLayer to be invoked before
  // drawing happens. This allows relayout to run once, rather many
  // times, and doesn't run until after all views have responded to
  // their notifications.

  self.needsDisplay = YES;
}

- (void)layoutSubviews
{
  layoutSubviews(self, -1, YES, NO);
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
  if (_ignoreLayout == 0)
    layoutSubviews(self, -1, YES, YES);
}

- (BOOL)wantsUpdateLayer
{
  return YES;
}

- (void)updateLayer
{
  layoutSubviews(self, -1, YES, YES);
}

- (BOOL)isFlipped
{
  return YES;
}

@end
