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

#import "ActViewController.h"

#import "ActWindowController.h"

@implementation ActViewController

@synthesize controller = _controller;
@synthesize identifierSuffix = _identifierSuffix;
@synthesize superviewController = _superviewController;
@synthesize viewHasBeenLoaded = _viewHasBeenLoaded;

+ (NSString *)viewNibName
{
  return nil;
}

+ (ActViewController *)viewControllerWithPropertyListRepresentation:(id)obj
    controller:(ActWindowController *)controller
{
  if (![obj isKindOfClass:[NSDictionary class]])
    return nil;

  NSDictionary *dict = obj;

  Class cls = NSClassFromString([dict objectForKey:@"className"]);
  if (![cls isSubclassOfClass:[ActViewController class]])
    return nil;

  return [[[cls alloc] initWithController:
	   controller options:dict] autorelease];
}

- (id)propertyListRepresentation
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  [dict setObject:NSStringFromClass([self class]) forKey:@"className"];

  if (_identifierSuffix != nil)
    [dict setObject:_identifierSuffix forKey:@"identifierSuffix"];

  return dict;
}

- (id)initWithController:(ActWindowController *)controller
    options:(NSDictionary *)opts
{
  self = [super initWithNibName:[[self class] viewNibName]
	  bundle:[NSBundle mainBundle]];
  if (self == nil)
    return nil;

  _controller = controller;
  _subviewControllers = [[NSMutableArray alloc] init];
  _identifierSuffix = [[opts objectForKey:@"identifierSuffix"] copy];

  return self;
}

- (void)dealloc
{
  [_subviewControllers release];
  [_identifierSuffix release];
  [super dealloc];
}

- (NSString *)identifier
{
  NSString *ident = NSStringFromClass([self class]);

  if (_identifierSuffix != nil)
    ident = [ident stringByAppendingString:_identifierSuffix];

  return ident;
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
  for (ActViewController *c in _subviewControllers)
    c->_superviewController = nil;

  [_subviewControllers release];
  _subviewControllers = [array mutableCopy];

  for (ActViewController *c in _subviewControllers)
    c->_superviewController = self;
}

- (void)addSubviewController:(ActViewController *)controller
{
  [_subviewControllers addObject:controller];
  controller->_superviewController = self;
}

- (void)addSubviewController:(ActViewController *)controller
    after:(ActViewController *)pred
{
  NSInteger idx = [_subviewControllers indexOfObjectIdenticalTo:pred];
  if (idx != NSNotFound)
    [_subviewControllers insertObject:controller atIndex:idx+1];
  else
    [_subviewControllers addObject:controller];
  controller->_superviewController = self;
}

- (void)removeSubviewController:(ActViewController *)controller
{
  NSInteger idx = [_subviewControllers indexOfObjectIdenticalTo:controller];

  if (idx != NSNotFound)
    {
      controller->_superviewController = nil;
      [_subviewControllers removeObjectAtIndex:idx];
    }
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
