// -*- c-style: gnu -*-

#import "ActActivityViewController.h"

#import "ActChartViewController.h"
#import "ActHeaderViewController.h"
#import "ActLapViewController.h"
#import "ActMapViewController.h"
#import "ActSummaryViewController.h"
#import "ActSplitView.h"
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

  [_controller addSplitView:_mainSplitView
   identifier:@"Window.activity.mainSplitView"];
  [_controller addSplitView:_topSplitView
   identifier:@"Window.activity.topSplitView"];
  [_controller addSplitView:_middleSplitView
   identifier:@"Window.activity.middleSplitView"];

  if (ActViewController *obj
      = [[ActSummaryViewController alloc] initWithController:_controller])
    {
      [_viewControllers addObject:obj];
      [obj addToContainerView:_topLeftContainer];
      [obj release];
    }

  if (ActViewController *obj
      = [[ActHeaderViewController alloc] initWithController:_controller])
    {
      [_viewControllers addObject:obj];
      [obj addToContainerView:_topRightContainer];
      [obj release];
    }

  if (ActViewController *obj
      = [[ActMapViewController alloc] initWithController:_controller])
    {
      [_viewControllers addObject:obj];
      [obj addToContainerView:_middleLeftContainer];
      [obj release];
    }

  if (ActViewController *obj
      = [[ActLapViewController alloc] initWithController:_controller])
    {
      [_viewControllers addObject:obj];
      [obj addToContainerView:_middleRightContainer];
      [obj release];
    }

  if (ActViewController *obj
      = [[ActChartViewController alloc] initWithController:_controller])
    {
      [_viewControllers addObject:obj];
      [obj addToContainerView:_bottomContainer];
      [obj release];
    }
}

- (ActViewController *)viewControllerWithClass:(Class)cls
{
  for (ActViewController *obj in _viewControllers)
    {
      obj = [obj viewControllerWithClass:cls];
      if (obj != nil)
	return obj;
    }

  return nil;
}

- (NSDictionary *)savedViewState
{
  NSMutableDictionary *controllers = [NSMutableDictionary dictionary];

  for (ActViewController *controller in _viewControllers)
    {
      if (NSDictionary *sub = [controller savedViewState])
	[controllers setObject:sub forKey:[controller identifier]];
    }

  return [NSDictionary dictionaryWithObjectsAndKeys:
	  controllers, @"ActViewControllers",
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
}

@end
