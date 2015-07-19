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

#import "ActAppDelegate.h"

#import "ActURLCache.h"
#import "ActWindowController.h"

@implementation ActAppDelegate

@synthesize viewMenu = _viewMenu;
@synthesize windowController = _windowController;

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
  [self.windowController showWindow:sender];
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

// NSMenuDelegate methods

- (void)menuNeedsUpdate:(NSMenu *)menu
{
  if (menu == _viewMenu)
    {
      for (NSMenuItem *item in menu.itemArray)
	{
	  SEL sel = item.action;
	  if (sel == @selector(setWindowModeAction:))
	    item.state = _windowController.windowMode == item.tag;
	  else if (sel == @selector(setListViewAction:))
	    item.state = _windowController.listViewType == item.tag;
	}
    }
}

@end
