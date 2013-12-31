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

#import "ActHeaderView.h"

#import "ActColor.h"
#import "ActCollapsibleView.h"
#import "ActHeaderFieldView.h"
#import "ActViewLayout.h"
#import "ActWindowController.h"

#import "ActFoundationExtensions.h"

#define FIELD_HEIGHT 12
#define FIELD_Y_SPACING 2
#define MIN_COLUMN_WIDTH 200
#define X_INSET 8
#define Y_INSET 8

@implementation ActHeaderView

- (ActWindowController *)controller
{
  return (ActWindowController *)[[self window] windowController];
}

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self == nil)
    return nil;

  return self;
}

- (void)viewDidLoad
{
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:[self controller]];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeField:)
   name:ActActivityDidChangeField object:[self controller]];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (NSArray *)displayedFields
{
  NSMutableArray *array = [[NSMutableArray alloc] init];

  for (ActHeaderFieldView *subview in [self subviews])
    {
      NSString *name = [subview fieldName];
      if ([name length] != 0)
	[array addObject:name];
    }

  return [array autorelease];
}

- (void)setDisplayedFields:(NSArray *)array
{
  NSMutableArray *old_subviews = [[self subviews] mutableCopy];
  NSMutableArray *new_subviews = [[NSMutableArray alloc] init];

  for (NSString *field in array)
    {
      ActHeaderFieldView *new_subview = nil;

      NSInteger old_idx = 0;
      for (ActHeaderFieldView *old_subview in old_subviews)
	{
	  if ([[old_subview fieldName] isEqualToStringNoCase:field])
	    {
	      new_subview = old_subview;
	      [old_subviews removeObjectAtIndex:old_idx];
	      break;
	    }
	  old_idx++;
	}

      if (new_subview == nil)
	{
	  new_subview = [[[ActHeaderFieldView alloc]
			  initWithFrame:NSZeroRect] autorelease];
	  [new_subview setHeaderView:self];
	  [new_subview setFieldName:field];
	}

      [new_subviews addObject:new_subview];
    }

  [self setSubviews:new_subviews];

  [new_subviews release];
  [old_subviews release];
}

- (ActHeaderFieldView *)_ensureField:(NSString *)name
{
  for (ActHeaderFieldView *subview in [self subviews])
    {
      if ([[subview fieldName] isEqualToStringNoCase:name])
	return subview;
    }

  ActHeaderFieldView *field
    = [[ActHeaderFieldView alloc] initWithFrame:NSZeroRect];

  [field setHeaderView:self];
  [field setFieldName:name];

  [self addSubview:field];
  [field release];

  return field;
}

- (BOOL)displaysField:(NSString *)name
{
  for (ActHeaderFieldView *subview in [self subviews])
    {
      if ([[subview fieldName] isEqualToStringNoCase:name])
	return YES;
    }

  return NO;
}

- (void)addDisplayedField:(NSString *)name
{
  [self _ensureField:name];
}

- (void)removeDisplayedField:(NSString *)name
{
  for (ActHeaderFieldView *subview in [self subviews])
    {
      if ([[subview fieldName] isEqualToStringNoCase:name])
	{
	  [subview removeFromSuperview];
	  return;
	}
    }
}

- (IBAction)controlAction:(id)sender
{
  if (sender == _addFieldButton)
    {
      ActHeaderFieldView *field = [self _ensureField:@""];
      [(ActCollapsibleView *)[_controller view] setCollapsed:NO];
      [[self superview] subviewNeedsLayout:self];
      [[self window] makeFirstResponder:[field nameView]];
      [self scrollRectToVisible:[field convertRect:[field bounds] toView:self]];
    }
}

- (void)selectFieldFollowing:(ActHeaderFieldView *)view
{
  BOOL previous = NO;

  for (ActHeaderFieldView *subview in [self subviews])
    {
      if (previous)
	{
	  [[self window] makeFirstResponder:[subview valueView]];
	  return;
	}
      else if (subview == view)
	previous = YES;
    }

  if (previous)
    {
      [self controlAction:_addFieldButton];
    }
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  for (ActHeaderFieldView *subview in [self subviews])
    [subview update];
}

- (void)activityDidChangeField:(NSNotification *)note
{
  NSDictionary *dict = [note userInfo];

  void *ptr = [[dict objectForKey:@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);
  
  if (a == [[self controller] selectedActivityStorage])
    {
      for (ActHeaderFieldView *subview in [self subviews])
	[subview update];
    }
}

- (CGFloat)heightForWidth:(CGFloat)width
{
  width = width - X_INSET * 2;

  int cols = (int) fmax(1, floor(width / MIN_COLUMN_WIDTH));
  int rows = ([[self subviews] count] + (cols - 1)) / cols;

  CGFloat h = 0, col_h = 0;
  int xi = 0, yi = 0;

  for (ActHeaderFieldView *field in [self subviews])
    {
      CGFloat fh = [field preferredHeight];

      if (yi != 0)
	col_h += FIELD_Y_SPACING;

      col_h += fh;

      if (++yi == rows)
	{
	  yi = 0;
	  xi++;
	  h = fmax(col_h, h);
	  col_h = 0;
	}
    }

  h = fmax(col_h, h);

  return h + Y_INSET * 2;
}

- (void)layoutSubviews
{
  NSRect bounds = NSInsetRect([self bounds], X_INSET, Y_INSET);

  int cols = (int) fmax(1, floor(bounds.size.width / MIN_COLUMN_WIDTH));
  int rows = ([[self subviews] count] + (cols - 1)) / cols;

  CGFloat col_w = floor(bounds.size.width / cols);

  int xi = 0, yi = 0;
  CGFloat y = 0;

  for (ActHeaderFieldView *field in [self subviews])
    {
      CGFloat fh = [field preferredHeight];

      NSRect frame;
      frame.origin.x = bounds.origin.x + xi * col_w;
      frame.origin.y = bounds.origin.y + bounds.size.height - (y + fh);
      frame.size.width = col_w;
      frame.size.height = fh;
      [field setFrame:frame];
      [field layoutSubviews];

      y += fh + FIELD_Y_SPACING;

      if (++yi == rows)
	{
	  xi++;
	  yi = 0;
	  y = 0;
	}
    }
}

- (void)drawRect:(NSRect)r
{
  [[ActColor controlBackgroundColor] setFill];
  [NSBezierPath fillRect:r];
}

@end
