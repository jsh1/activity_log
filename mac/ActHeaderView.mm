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
#import "ActHeaderViewController.h"
#import "ActViewLayout.h"
#import "ActWindowController.h"

#import "FoundationExtensions.h"

#define FIELD_HEIGHT 12
#define FIELD_Y_SPACING 2
#define X_INSET 8
#define Y_INSET 8

@implementation ActHeaderView

- (ActWindowController *)controller
{
  return (ActWindowController *)self.window.windowController;
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
   name:ActSelectedActivityDidChange object:self.controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeField:)
   name:ActActivityDidChangeField object:self.controller];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (NSArray *)displayedFields
{
  NSMutableArray *array = [[NSMutableArray alloc] init];

  for (ActHeaderFieldView *subview in self.subviews)
    {
      NSString *name = subview.fieldName;
      if (name.length != 0)
	[array addObject:name];
    }

  return [array autorelease];
}

- (void)setDisplayedFields:(NSArray *)array
{
  NSMutableArray *old_subviews = [self.subviews mutableCopy];
  NSMutableArray *new_subviews = [[NSMutableArray alloc] init];

  for (NSString *field in array)
    {
      ActHeaderFieldView *new_subview = nil;

      NSInteger old_idx = 0;
      for (ActHeaderFieldView *old_subview in old_subviews)
	{
	  if ([old_subview.fieldName
	       isEqualToString:field caseInsensitive:YES])
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
	  new_subview.headerView = self;
	  new_subview.fieldName = field;
	}

      [new_subviews addObject:new_subview];
    }

  self.subviews = new_subviews;

  [new_subviews release];
  [old_subviews release];
}

- (ActHeaderFieldView *)_ensureField:(NSString *)name
{
  for (ActHeaderFieldView *subview in self.subviews)
    {
      if ([subview.fieldName isEqualToString:name caseInsensitive:YES])
	return subview;
    }

  ActHeaderFieldView *field
    = [[ActHeaderFieldView alloc] initWithFrame:NSZeroRect];

  field.headerView = self;
  field.fieldName = name;

  [self addSubview:field];
  [field release];

  return field;
}

- (BOOL)displaysField:(NSString *)name
{
  for (ActHeaderFieldView *subview in self.subviews)
    {
      if ([subview.fieldName isEqualToString:name caseInsensitive:YES])
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
  for (ActHeaderFieldView *subview in self.subviews)
    {
      if ([subview.fieldName isEqualToString:name caseInsensitive:YES])
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
      ((ActCollapsibleView *)_controller.view).collapsed = NO;
      [self.superview subviewNeedsLayout:self];
      [self.window makeFirstResponder:field.nameView];
      [self scrollRectToVisible:[field convertRect:field.bounds toView:self]];
    }
}

- (void)selectFieldFollowing:(ActHeaderFieldView *)view
{
  BOOL previous = NO;

  for (ActHeaderFieldView *subview in self.subviews)
    {
      if (previous)
	{
	  [self.window makeFirstResponder:subview.valueView];
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
  for (ActHeaderFieldView *subview in self.subviews)
    [subview update];
}

- (void)activityDidChangeField:(NSNotification *)note
{
  NSDictionary *dict = note.userInfo;

  void *ptr = [dict[@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);
  
  if (a == self.controller.selectedActivityStorage)
    {
      for (ActHeaderFieldView *subview in self.subviews)
	[subview update];
    }
}

- (CGFloat)heightForWidth:(CGFloat)width
{
  CGFloat h = 0;

  for (ActHeaderFieldView *field in self.subviews)
    {
      if (h != 0)
       h += FIELD_Y_SPACING;
      h += field.preferredHeight;
    }

  return h + Y_INSET * 2;
}

- (void)layoutSubviews
{
  NSRect bounds = NSInsetRect(self.bounds, X_INSET, Y_INSET);

  CGFloat y = 0;

  for (ActHeaderFieldView *field in self.subviews)
    {
      NSRect frame;
      CGFloat h = field.preferredHeight;
      frame.origin.x = bounds.origin.x;
      frame.origin.y = bounds.origin.y + bounds.size.height - (y + h);
      frame.size.width = bounds.size.width;
      frame.size.height = h;
      field.frame = frame;
      [field layoutSubviews];
      y += h + FIELD_Y_SPACING;
    }
}

- (void)drawRect:(NSRect)r
{
  [[ActColor controlBackgroundColor] setFill];
  [NSBezierPath fillRect:r];
}

- (BOOL)isOpaque
{
  return YES;
}

@end
