// -*- c-style: gnu -*-

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

- (NSInteger)subitemsCount;

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
