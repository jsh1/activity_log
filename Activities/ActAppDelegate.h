// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

@class ActWindowController;

@interface ActAppDelegate : NSObject <NSApplicationDelegate>
{
  ActWindowController *_windowController;
}

@property(readonly) ActWindowController *windowController;

- (IBAction)showWindow:(id)sender;

@end
