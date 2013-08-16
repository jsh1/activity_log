// -*- c-style: gnu -*-

#import "ActAppDelegate.h"

#import "ActWindowController.h"

@implementation ActAppDelegate

- (void)dealloc
{
  [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
  [self showWindow:self];
}

- (IBAction)showWindow:(id)sender
{
  [[self windowController] showWindow:sender];
}

- (NSWindowController *)windowController
{
  if (_windowController == nil)
    _windowController = [[ActWindowController alloc] init];

  return _windowController;
}

@end
