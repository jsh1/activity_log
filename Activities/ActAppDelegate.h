// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

@class ActWindowController;

@interface ActAppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>
{
  IBOutlet NSMenu *_viewMenu;

  ActWindowController *_windowController;
}

@property(readonly) ActWindowController *windowController;

@property(readonly) NSLocale *currentLocale;

- (IBAction)showWindow:(id)sender;

- (IBAction)emptyCaches:(id)sender;

@end
