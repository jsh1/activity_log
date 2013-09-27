// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

#import "act-activity-storage.h"

@class ActWindowController;

@interface ActViewController : NSViewController
{
  ActWindowController *_controller;
}

+ (NSString *)viewNibName;
- (NSString *)identifier;

- (id)initWithController:(ActWindowController *)controller;

- (void)viewDidLoad;

@property(nonatomic, readonly) ActWindowController *controller;

@property(nonatomic, readonly) NSView *initialFirstResponder;

- (NSDictionary *)savedViewState;
- (void)applySavedViewState:(NSDictionary *)dict;

@end
