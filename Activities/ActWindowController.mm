// -*- c-style: gnu -*-

#import "ActWindowController.h"

@implementation ActWindowController

- (NSString *)windowNibName
{
  return @"ActWindow";
}

- (id)init
{
  return [super initWithWindow:nil];
}

- (void)dealloc
{
  delete _database;
  [super dealloc];
}

- (act::database *)database
{
  if (_database == nil)
    _database = new act::database();

  return _database;
}

- (void)windowDidLoad
{
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(windowWillClose:)
   name:NSWindowWillCloseNotification object:[self window]];
}

- (void)windowWillClose:(NSNotification *)note
{
  [NSApp terminate:self];
}

@end
