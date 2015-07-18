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

#import <Foundation/Foundation.h>

@class ActWindowController;

@interface ActSourceListItem : NSObject
{
  ActWindowController *_controller;
  NSString *_name;
  NSMutableArray *_subitems;
  BOOL _expandable;
}

+ (id)item;
+ (id)itemWithName:(NSString *)name;

@property(nonatomic, assign) ActWindowController *controller;

@property(nonatomic, copy) NSString *name;

@property(nonatomic, copy) NSArray *subitems;

// can be overridden if more efficient than [self.subitems count]

@property(nonatomic, readonly) NSInteger subitemsCount;

@property(nonatomic, getter=isExpandable) BOOL expandable;

- (void)addSubitem:(ActSourceListItem *)item;
- (void)removeSubitem:(ActSourceListItem *)item;

@property(nonatomic, readonly) BOOL hasBadge;
@property(nonatomic, readonly) NSInteger badgeValue;

@property(nonatomic, readonly) BOOL hasIcon;
@property(nonatomic, readonly) NSImage *iconImage;

- (void)select;

- (void)foreachItem:(void(^)(ActSourceListItem *item))block;

@end
