// -*- c-style: gnu -*-

#import "ActViewController.h"

#import "ActWindowController.h"

@implementation ActViewController

@synthesize controller = _controller;

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
  return self;
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

  if ([self view] != nil)
    [self viewDidLoad];
}

- (NSDictionary *)savedViewState
{
  return nil;
}

- (void)applySavedViewState:(NSDictionary *)dict
{
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

- (ActViewController *)viewControllerWithClass:(Class)cls
{
  if ([self class] == cls)
    return self;
  else
    return nil;
}

// ActActivityTextFieldDelegate methods

- (ActFieldEditor *)actFieldEditor:(ActTextField *)obj
{
  return [_controller fieldEditor];
}

@end
