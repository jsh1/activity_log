// -*- c-style: gnu -*-

#import "ActTextField.h"

#import "act-activity-storage.h"

@class ActWindowController;

@interface ActViewController : NSViewController <ActTextFieldDelegate>
{
  ActWindowController *_controller;

  NSMutableArray *_subviewControllers;

  BOOL _viewHasBeenLoaded;
}

+ (NSString *)viewNibName;
- (NSString *)identifier;

- (id)initWithController:(ActWindowController *)controller;

@property(nonatomic, readonly) BOOL viewHasBeenLoaded;

- (void)viewDidLoad;

@property(nonatomic, readonly) ActWindowController *controller;

- (ActViewController *)viewControllerWithClass:(Class)cls;

@property(nonatomic, copy) NSArray *subviewControllers;

- (void)addSubviewController:(ActViewController *)controller;
- (void)removeSubviewController:(ActViewController *)controller;

@property(nonatomic, readonly) NSView *initialFirstResponder;

- (NSDictionary *)savedViewState;
- (void)applySavedViewState:(NSDictionary *)dict;

- (void)addToContainerView:(NSView *)view;
- (void)removeFromContainer;

@end
