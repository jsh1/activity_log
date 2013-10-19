// -*- c-style: gnu -*-

#import "ActActivityViewController.h"

#import "ActChartViewController.h"
#import "ActCollapsibleView.h"
#import "ActHeaderViewController.h"
#import "ActLapViewController.h"
#import "ActMapViewController.h"
#import "ActSummaryViewController.h"
#import "ActViewLayout.h"
#import "ActWindowController.h"

@implementation ActActivityViewController

- (NSString *)viewNibName
{
  return @"ActActivityView";
}

- (id)initWithController:(ActWindowController *)controller
{
  self = [super initWithController:controller];
  if (self == nil)
    return nil;

  _viewControllers = [[NSMutableArray alloc] init];

  return self;
}

- (void)dealloc
{
  [_viewControllers release];

  [super dealloc];
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  if (ActViewController *obj
      = [[ActSummaryViewController alloc] initWithController:_controller])
    {
      [_viewControllers addObject:obj];
      [_activityView addSubview:[obj view]];
      [obj release];
    }

  // FIXME: these should be configurable and persistent

  if (ActViewController *obj
      = [[ActHeaderViewController alloc] initWithController:_controller])
    {
      [_viewControllers addObject:obj];
      [_activityView addSubview:[obj view]];
      [obj release];
    }

  if (ActViewController *obj
      = [[ActLapViewController alloc] initWithController:_controller])
    {
      [_viewControllers addObject:obj];
      [_activityView addSubview:[obj view]];
      [obj release];
    }

  if (ActViewController *obj
      = [[ActMapViewController alloc] initWithController:_controller])
    {
      [_viewControllers addObject:obj];
      [_activityView addSubview:[obj view]];
      [obj release];
    }

  if (ActViewController *obj
      = [[ActChartViewController alloc] initWithController:_controller])
    {
      [_viewControllers addObject:obj];
      [_activityView addSubview:[obj view]];
      [obj release];
    }

  [_activityView subviewNeedsLayout:nil];
}

- (ActViewController *)viewControllerWithClass:(Class)cls
{
  for (ActViewController *obj in _viewControllers)
    {
      obj = [obj viewControllerWithClass:cls];
      if (obj != nil)
	return obj;
    }

  return [super viewControllerWithClass:cls];
}

- (NSDictionary *)savedViewState
{
  NSMutableDictionary *controllers = [NSMutableDictionary dictionary];
  NSMutableDictionary *collapsed = [NSMutableDictionary dictionary];

  for (ActViewController *controller in _viewControllers)
    {
      if (NSDictionary *sub = [controller savedViewState])
	[controllers setObject:sub forKey:[controller identifier]];

      ActCollapsibleView *view = (id)[controller view];
      if ([view isKindOfClass:[ActCollapsibleView class]]
	  && [view isCollapsed])
	[collapsed setObject:@YES forKey:[controller identifier]];
    }

  return [NSDictionary dictionaryWithObjectsAndKeys:
	  controllers, @"ActViewControllers",
	  collapsed, @"ActViewCollapsed",
	  nil];
}

- (void)applySavedViewState:(NSDictionary *)state
{
  if (NSDictionary *dict = [state objectForKey:@"ActViewControllers"])
    {
      for (ActViewController *controller in _viewControllers)
	{
	  if (NSDictionary *sub = [dict objectForKey:[controller identifier]])
	    [controller applySavedViewState:sub];
	}
    }

  if (NSDictionary *dict = [state objectForKey:@"ActViewCollapsed"])
    {
      for (ActViewController *controller in _viewControllers)
	{
	  if (NSNumber *obj = [dict objectForKey:[controller identifier]])
	    [(ActCollapsibleView *)[controller view] setCollapsed:[obj boolValue]];
	}
    }
}

@end

@implementation ActActivityView

static CGFloat
layoutSubviews(ActActivityView *self, CGFloat width,
	       BOOL modifySubviews, BOOL updateHeight)
{
  NSRect bounds = [self bounds];
  CGFloat y = 0;

  if (width < 0)
    width = bounds.size.width;

  self->_ignoreLayout++;

  for (NSView *view in [self subviews])
    {
      CGFloat height = [view heightForWidth:width];

      if (modifySubviews)
	{
	  NSRect frame;
	  frame.origin.x = bounds.origin.x;
	  frame.origin.y = bounds.origin.y + y;
	  frame.size.width = bounds.size.width;
	  frame.size.height = height;

	  if (!NSEqualRects(frame, [view frame]))
	    {
	      [view setFrame:frame];
	      [view layoutSubviews];
	    }
	}

      y += height;
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
  layoutSubviews(self, -1, YES, YES);
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

- (BOOL)isFlipped
{
  return YES;
}

@end
