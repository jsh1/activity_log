// -*- c-style: gnu -*-

#import "ActSourceListItem.h"

@implementation ActSourceListItem

@synthesize name = _name;
@synthesize expandable = _expandable;
@synthesize controller = _controller;

+ (id)item
{
  return [[[self alloc] init] autorelease];
}

+ (id)itemWithName:(NSString *)name
{
  ActSourceListItem *item = [self item];
  [item setName:name];
  return item;
}

- (void)dealloc
{
  [_name release];
  [_subitems release];
  [super dealloc];
}

- (NSArray *)subitems
{
  return _subitems != nil ? _subitems : [NSArray array];
}

- (void)setSubitems:(NSArray *)array
{
  if (_subitems != array)
    {
      [_subitems release];
      _subitems = [array mutableCopy];
    }
}

- (NSInteger)subitemsCount
{
  return [_subitems count];
}

- (void)addSubitem:(ActSourceListItem *)item
{
  if (_subitems == nil
      || [_subitems indexOfObjectIdenticalTo:item] == NSNotFound)
    {
      if (_subitems == nil)
	_subitems = [[NSMutableArray alloc] init];
      [_subitems addObject:item];
    }
}

- (void)removeSubitem:(ActSourceListItem *)item
{
  if (_subitems != nil)
    {
      NSInteger idx = [_subitems indexOfObjectIdenticalTo:item];
      if (idx != NSNotFound)
	[_subitems removeObjectAtIndex:idx];
    }
}

- (BOOL)hasBadge
{
  return NO;
}

- (NSInteger)badgeValue
{
  return 0;
}

- (BOOL)hasIcon
{
  return NO;
}

- (NSImage *)iconImage
{
  return nil;
}

- (void)select
{
}

- (void)foreachItem:(void(^)(ActSourceListItem *item))block
{
  block(self);

  for (ActSourceListItem *subitem in _subitems)
    [subitem foreachItem:block];
}

@end
