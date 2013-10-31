// -*- c-style: gnu -*-

#import "ActViewController.h"

#import "ActWindowController.h"

@implementation ActViewController

@synthesize controller = _controller;
@synthesize viewHasBeenLoaded = _viewHasBeenLoaded;

+ (NSString *)viewNibName
{
  return nil;
}

- (NSString *)identifier
{
  return NSStringFromClass([self class]);
}

- (id)initWithController:(ActWindowController *)controller
{
  self = [super initWithNibName:[[self class] viewNibName]
	  bundle:[NSBundle mainBundle]];
  if (self == nil)
    return nil;

  _controller = controller;
  _subviewControllers = [[NSMutableArray alloc] init];

  return self;
}

- (void)dealloc
{
  [_subviewControllers release];
  [super dealloc];
}

- (ActViewController *)viewControllerWithClass:(Class)cls
{
  if ([self class] == cls)
    return self;

  for (ActViewController *obj in _subviewControllers)
    {
      obj = [obj viewControllerWithClass:cls];
      if (obj != nil)
	return obj;
    }

  return nil;
}

- (NSArray *)subviewControllers
{
  return _subviewControllers;
}

- (void)setSubviewControllers:(NSArray *)array
{
  [_subviewControllers release];
  _subviewControllers = [array mutableCopy];
}

- (void)addSubviewController:(ActViewController *)controller
{
  [_subviewControllers addObject:controller];
}

- (void)removeSubviewController:(ActViewController *)controller
{
  NSInteger idx = [_subviewControllers indexOfObjectIdenticalTo:controller];

  if (idx != NSNotFound)
    [_subviewControllers removeObjectAtIndex:idx];
}

- (NSView *)initialFirstResponder
{
  return nil;
}

- (void)viewDidLoad
{
}

- (void)loadView
{
  [super loadView];

  _viewHasBeenLoaded = YES;

  if ([self view] != nil)
    [self viewDidLoad];
}

- (NSDictionary *)savedViewState
{
  if ([_subviewControllers count] == 0)
    return [NSDictionary dictionary];

  NSMutableDictionary *controllers = [NSMutableDictionary dictionary];

  for (ActViewController *controller in _subviewControllers)
    {
      NSDictionary *sub = [controller savedViewState];
      if ([sub count] != 0)
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
      for (ActViewController *controller in _subviewControllers)
	{
	  if (NSDictionary *sub = [dict objectForKey:[controller identifier]])
	    [controller applySavedViewState:sub];
	}
    }
}

- (void)addToContainerView:(NSView *)superview
{
  if (NSView *view = [self view])
    {
      assert([view superview] == nil);
      [view setFrame:[superview bounds]];
      [superview addSubview:view];
    }
}

- (void)removeFromContainer
{
  [[self view] removeFromSuperview];
}

// ActActivityTextFieldDelegate methods

- (ActFieldEditor *)actFieldEditor:(ActTextField *)obj
{
  return [_controller fieldEditor];
}

@end
