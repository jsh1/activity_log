// -*- c-style: gnu -*-

#import "ActTextField.h"

#import "act-activity-storage.h"

@class ActWindowController;

@interface ActViewController : NSViewController <ActTextFieldDelegate>
{
  ActWindowController *_controller;
}

+ (NSColor *)textFieldColor:(BOOL)readOnly;
+ (NSColor *)redTextFieldColor:(BOOL)readOnly;

+ (NSString *)viewNibName;
- (NSString *)identifier;

- (id)initWithController:(ActWindowController *)controller;

- (void)viewDidLoad;

@property(nonatomic, readonly) ActWindowController *controller;

@property(nonatomic, readonly) NSView *initialFirstResponder;

- (NSDictionary *)savedViewState;
- (void)applySavedViewState:(NSDictionary *)dict;

- (void)addToContainerView:(NSView *)view;
- (void)removeFromContainer;

- (ActViewController *)viewControllerWithClass:(Class)cls;

@end
