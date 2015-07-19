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

#import "ActHeaderFieldView.h"

#import "ActColor.h"
#import "ActHeaderView.h"
#import "ActWindowController.h"

#import "act-database.h"

#define LABEL_WIDTH 140
#define LABEL_HEIGHT 14
#define SPACING 8

#define CONTROL_HEIGHT LABEL_HEIGHT

@implementation ActHeaderFieldView
{
  ActTextField *_labelField;
  ActTextField *_valueField;

  NSString *_fieldName;
  int _depth;
}

@synthesize headerView = _headerView;

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self == nil)
    return nil;

  NSFont *font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
  NSFont *font1 = [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]];

  _labelField = [[ActTextField alloc] initWithFrame:
		 NSMakeRect(0, 0, LABEL_WIDTH, LABEL_HEIGHT)];
  _labelField.target = self;
  _labelField.action = @selector(controlAction:);
  _labelField.delegate = self;
  _labelField.drawsBackground = NO;
  _labelField.alignment = NSRightTextAlignment;
  NSTextFieldCell *cell = _labelField.cell;
  cell.bordered = NO;
  cell.font = font;
  cell.textColor = [ActColor controlTextColor];
  [self addSubview:_labelField];

  _valueField = [[ActTextField alloc] initWithFrame:
		 NSMakeRect(LABEL_WIDTH + SPACING, 0, frame.size.width
			    - LABEL_WIDTH, CONTROL_HEIGHT)];
  _valueField.target = self;
  _valueField.action = @selector(controlAction:);
  _valueField.delegate = self;
  _valueField.drawsBackground = NO;
  cell = _valueField.cell;
  cell.bordered = NO;
  cell.font = font1;
  cell.textColor = [ActColor controlTextColor];
  [self addSubview:_valueField];

  return self;
}

- (void)dealloc
{
  [_labelField setDelegate:nil];
  [_valueField setDelegate:nil];


}

- (ActWindowController *)controller
{
  return (ActWindowController *)self.window.windowController;
}

- (NSString *)fieldName
{
  return _fieldName;
}

- (void)_updateFieldName
{
  _labelField.stringValue = _fieldName;
  ((NSTextFieldCell *)_labelField.cell).truncatesLastVisibleLine = YES;

  BOOL readOnly = [self.controller isFieldReadOnly:_fieldName];
  NSTextFieldCell *cell = _valueField.cell;
  cell.editable = !readOnly;
  cell.textColor = [ActColor controlTextColor:readOnly];
  cell.truncatesLastVisibleLine = YES;

  _labelField.completesEverything = YES;
  _valueField.completesEverything = [_fieldName isEqualToString:@"Course"];
}

- (void)setFieldName:(NSString *)name
{
  if (_fieldName != name)
    {
      _fieldName = [name copy];

      [self _updateFieldName];
    }
}

- (NSString *)fieldString
{
  if (_fieldName.length != 0)
    return [self.controller stringForField:_fieldName];
  else
    return _valueField.stringValue;
}

- (void)setFieldString:(NSString *)str
{
  if (_fieldName.length != 0)
    {
      ActWindowController *controller = self.controller;
      if (![str isEqual:[controller stringForField:_fieldName]])
	[controller setString:str forField:_fieldName];
    }
  else
    _valueField.stringValue = str;
}

- (void)renameField:(NSString *)newName
{
  if (![newName isEqualToString:_fieldName])
    {
      ActWindowController *controller = self.controller;

      NSString *oldName = _fieldName;
      _fieldName = [newName copy];
      newName = _fieldName;

      [self _updateFieldName];

      if (oldName.length != 0)
	{
	  if (newName.length != 0)
	    [controller renameField:oldName to:newName];
	  else
	    [controller deleteField:oldName];
	}
      else if (newName.length != 0)
	[controller setString:_valueField.stringValue forField:newName];

    }
}

- (NSView *)nameView
{
  return _labelField;
}

- (NSView *)valueView
{
  return _valueField;
}

- (void)update
{
  // reload everything in case of dependent fields (pace, etc)

  [self _updateFieldName];
  _valueField.stringValue = self.fieldString;
}

- (CGFloat)preferredHeight
{
  return CONTROL_HEIGHT;
}

- (void)layoutSubviews
{
  NSRect bounds = self.bounds;
  NSRect frame = bounds;

  frame.size.width = LABEL_WIDTH;
  _labelField.frame = frame;

  frame.origin.x += frame.size.width + SPACING;
  frame.size.width = bounds.size.width - frame.origin.x;
  _valueField.frame = frame;
}

- (IBAction)controlAction:(id)sender
{
  if (sender == _labelField)
    [self renameField:[sender stringValue]];
  else if (sender == _valueField)
    self.fieldString = [sender stringValue];

  NSEvent *e = self.window.currentEvent;
  if (e.type == NSKeyDown
      && [e.charactersIgnoringModifiers isEqualToString:@"\r"]
      && _depth == 0)
    {
      if (sender == _labelField)
	[self.window makeFirstResponder:_valueField];
      else
	[_headerView selectFieldFollowing:self];
    }
}

// NSControlTextEditingDelegate methods

- (BOOL)control:(NSControl *)control
    textShouldEndEditing:(NSText *)fieldEditor
{
  _depth++;
  [self controlAction:control];
  _depth--;
  return YES;
}

- (NSArray *)control:(NSControl *)control textView:(NSTextView *)textView
    completions:(NSArray *)words forPartialWordRange:(NSRange)charRange
    indexOfSelectedItem:(NSInteger *)index
{
  if (control == _labelField || control == _valueField)
    {
      if (control == _valueField && _fieldName.length == 0)
	return nil;

      NSString *str = [textView.string substringWithRange:charRange];

      act::database *db = self.controller.database;

      std::vector<std::string> completions;
      if (control == _labelField)
	{
	  db->complete_field_name(str.UTF8String, completions);
	}
      else
	{
	  db->complete_field_value(_fieldName.UTF8String,
				   str.UTF8String, completions);
	}

      NSMutableArray *array = [NSMutableArray array];
      for (const auto &it : completions)
	[array addObject:@(it.c_str())];

      return array;
    }

  return nil;
}

// ActTextFieldDelegate methods

- (ActFieldEditor *)actFieldEditor:(ActTextField *)obj
{
  return self.controller.fieldEditor;
}

@end
