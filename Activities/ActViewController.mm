// -*- c-style: gnu -*-

#import "ActViewController.h"

#import "ActWindowController.h"

@implementation ActViewController

@synthesize controller = _controller;

+ (NSColor *)textFieldColor:(BOOL)readOnly
{
  static NSColor *a, *b;

  if (a == nil)
    {
      a = [[NSColor colorWithDeviceWhite:.25 alpha:1] retain];
      b = [[NSColor colorWithDeviceWhite:.45 alpha:1] retain];
    }

  return !readOnly ? a : b;
}

+ (NSColor *)redTextFieldColor:(BOOL)readOnly
{
  static NSColor *a, *b;

  if (a == nil)
    {
      a = [[NSColor colorWithDeviceRed:197/255. green:56/255. blue:51/255. alpha:1] retain];
      b = [[NSColor colorWithDeviceRed:197/255. green:121/255. blue:118/255. alpha:1] retain];
    }

  return !readOnly ? a : b;
}

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
