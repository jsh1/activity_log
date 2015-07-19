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

#import "ActSourceListItem.h"

@implementation ActSourceListItem
{
  NSMutableArray *_subitems;
}

@synthesize controller = _controller;
@synthesize name = _name;
@synthesize expandable = _expandable;

+ (id)item
{
  return [[self alloc] init];
}

+ (id)itemWithName:(NSString *)name
{
  ActSourceListItem *item = [self item];
  item.name = name;
  return item;
}


- (NSArray *)subitems
{
  return _subitems != nil ? _subitems : @[];
}

- (void)setSubitems:(NSArray *)array
{
  if (_subitems != array)
    {
      _subitems = [array mutableCopy];
    }
}

- (NSInteger)subitemsCount
{
  return _subitems.count;
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
