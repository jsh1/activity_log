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

@end
