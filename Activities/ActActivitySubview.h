// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

@class ActActivityViewController;

@interface ActActivitySubview : NSView
{
  IBOutlet ActActivityViewController *_controller;
}

@property(nonatomic, assign) ActActivityViewController *controller;

- (void)drawBackgroundRect:(NSRect)r;

@end

@interface NSView (ActActivitySubview)

- (void)activityDidChange;
- (void)activityDidChangeField:(NSString *)name;
- (void)activityDidChangeBody;
- (void)selectedLapDidChange;

@end
