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

#import "ActTextField.h"

#import "act-activity-storage.h"

@class ActWindowController;

@interface ActViewController : NSViewController <ActTextFieldDelegate>

+ (NSString *)viewNibName;

+ (ActViewController *)viewControllerWithPropertyListRepresentation:(id)obj
    controller:(ActWindowController *)controller;

- (id)propertyListRepresentation;

@property(nonatomic, readonly, copy) NSString *identifier;
@property(nonatomic, readonly, copy) NSString *identifierSuffix;

- (id)initWithController:(ActWindowController *)controller
    options:(NSDictionary *)dict;

- (void)viewWillAppear;
- (void)viewDidAppear;

- (void)viewWillDisappear;
- (void)viewDidDisappear;

@property(weak, nonatomic, readonly) ActWindowController *controller;

- (ActViewController *)viewControllerWithClass:(Class)cls;

@property(weak, nonatomic, readonly) ActViewController *superviewController;
@property(nonatomic, copy) NSArray *subviewControllers;

- (void)addSubviewController:(ActViewController *)controller;
- (void)addSubviewController:(ActViewController *)controller
    after:(ActViewController *)pred;
- (void)removeSubviewController:(ActViewController *)controller;

@property(weak, nonatomic, readonly) NSView *initialFirstResponder;

- (NSDictionary *)savedViewState;
- (void)applySavedViewState:(NSDictionary *)dict;

- (void)addToContainerView:(NSView *)view;
- (void)removeFromContainer;

@end
