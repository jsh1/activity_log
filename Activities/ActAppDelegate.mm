// -*- c-style: gnu -*-

#import "ActAppDelegate.h"

#import "ActURLCache.h"
#import "ActWindowController.h"

@implementation ActAppDelegate

- (void)dealloc
{
  [_windowController release];

  [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
  if (NSString *path = [[NSBundle mainBundle]
			pathForResource:@"defaults" ofType:@"plist"])
    {
      if (NSData *data = [NSData dataWithContentsOfFile:path])
	{
	  if (NSDictionary *dict
	      = [NSPropertyListSerialization propertyListWithData:data
		 options:NSPropertyListImmutable format:nil error:nil])
	    {
	      [[NSUserDefaults standardUserDefaults] registerDefaults:dict];
	    }
	}
    }

  [self showWindow:self];
}

- (void)applicationWillTerminate:(NSNotification *)note
{
  [_windowController synchronize];
  [[ActURLCache sharedURLCache] pruneCaches];
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

- (NSLocale *)currentLocale
{
  // allow system locale to be overridden by a hidden default

  static BOOL initialized;
  static NSLocale *locale;

  if (!initialized)
    {
      if (NSString *str = [[NSUserDefaults standardUserDefaults]
			   stringForKey:@"ActLocaleIdentifier"])
	{
	  locale = [[NSLocale alloc] initWithLocaleIdentifier:str];
	}
      initialized = YES;
    }

  return locale != nil ? locale : [NSLocale autoupdatingCurrentLocale];
}

- (IBAction)emptyCaches:(id)sender
{
  [[ActURLCache sharedURLCache] emptyCaches];
}

@end
