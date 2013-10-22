// -*- c-style: gnu -*-

#import "ActHeaderFieldView.h"

#import "ActColor.h"
#import "ActHeaderView.h"
#import "ActWindowController.h"

#import "act-database.h"

#define LABEL_WIDTH 100
#define LABEL_HEIGHT 14
#define SPACING 8

#define CONTROL_HEIGHT LABEL_HEIGHT

@implementation ActHeaderFieldView

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self == nil)
    return nil;

  NSFont *font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];

  _labelField = [[ActTextField alloc] initWithFrame:
		 NSMakeRect(0, 0, LABEL_WIDTH, LABEL_HEIGHT)];
  [_labelField setTarget:self];
  [_labelField setAction:@selector(controlAction:)];
  [_labelField setDelegate:self];
  [_labelField setDrawsBackground:NO];
  [[_labelField cell] setAlignment:NSRightTextAlignment];
  [[_labelField cell] setBordered:NO];
  [[_labelField cell] setFont:font];
  [[_labelField cell] setTextColor:[NSColor colorWithDeviceWhite:.25 alpha:1]];
  [self addSubview:_labelField];
  [_labelField release];

  _valueField = [[ActTextField alloc] initWithFrame:
		 NSMakeRect(LABEL_WIDTH + SPACING, 0, frame.size.width
			    - LABEL_WIDTH, CONTROL_HEIGHT)];
  [_valueField setTarget:self];
  [_valueField setAction:@selector(controlAction:)];
  [_valueField setDelegate:self];
  [_valueField setDrawsBackground:NO];
  [[_valueField cell] setBordered:NO];
  [[_valueField cell] setFont:font];
  [[_valueField cell] setTextColor:[NSColor colorWithDeviceWhite:.1 alpha:1]];
  [self addSubview:_valueField];
  [_valueField release];

  return self;
}

- (void)dealloc
{
  [_labelField setDelegate:nil];
  [_valueField setDelegate:nil];

  [_fieldName release];

  [super dealloc];
}

- (ActWindowController *)controller
{
  return (ActWindowController *)[[self window] windowController];
}

- (NSString *)fieldName
{
  return _fieldName;
}

- (void)_updateFieldName
{
  [_labelField setStringValue:_fieldName];
  [[_labelField cell] setTruncatesLastVisibleLine:YES];

  BOOL readOnly = [[self controller] isFieldReadOnly:_fieldName];
  [[_valueField cell] setEditable:!readOnly];
  [[_valueField cell] setTextColor:[ActColor controlTextColor:readOnly]];
  [[_valueField cell] setTruncatesLastVisibleLine:YES];

  [_labelField setCompletesEverything:YES];
  [_valueField setCompletesEverything:[_fieldName isEqualToString:@"Course"]];
}

- (void)setFieldName:(NSString *)name
{
  if (_fieldName != name)
    {
      [_fieldName release];
      _fieldName = [name copy];

      [self _updateFieldName];
    }
}

- (NSString *)fieldString
{
  if ([_fieldName length] != 0)
    return [[self controller] stringForField:_fieldName];
  else
    return [_valueField stringValue];
}

- (void)setFieldString:(NSString *)str
{
  if ([_fieldName length] != 0)
    {
      ActWindowController *controller = [self controller];
      if (![str isEqual:[controller stringForField:_fieldName]])
	[controller setString:str forField:_fieldName];
    }
  else
    [_valueField setStringValue:str];
}

- (void)renameField:(NSString *)newName
{
  if (![newName isEqualToString:_fieldName])
    {
      ActWindowController *controller = [self controller];

      NSString *oldName = _fieldName;
      _fieldName = [newName copy];
      newName = _fieldName;

      [self _updateFieldName];

      if ([oldName length] != 0)
	{
	  if ([newName length] != 0)
	    [controller renameField:oldName to:newName];
	  else
	    [controller deleteField:oldName];
	}
      else if ([newName length] != 0)
	[controller setString:[_valueField stringValue] forField:newName];

      [oldName release];
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
  [_valueField setStringValue:[self fieldString]];
}

- (CGFloat)preferredHeight
{
  return CONTROL_HEIGHT;
}

- (void)layoutSubviews
{
  NSRect bounds = [self bounds];
  NSRect frame = bounds;

  frame.size.width = LABEL_WIDTH;
  [_labelField setFrame:frame];

  frame.origin.x += frame.size.width + SPACING;
  frame.size.width = bounds.size.width - frame.origin.x;
  [_valueField setFrame:frame];
}

- (IBAction)controlAction:(id)sender
{
  if (sender == _labelField)
    [self renameField:[sender stringValue]];
  else if (sender == _valueField)
    [self setFieldString:[sender stringValue]];

  NSEvent *e = [[self window] currentEvent];
  if ([e type] == NSKeyDown
      && [[e charactersIgnoringModifiers] isEqualToString:@"\r"])
    {
      if (sender == _labelField)
	[[self window] makeFirstResponder:_valueField];
      else
	[_headerView selectFieldFollowing:self];
    }
}

// NSControlTextEditingDelegate methods

- (BOOL)control:(NSControl *)control
    textShouldEndEditing:(NSText *)fieldEditor
{
  [self controlAction:control];
  return YES;
}

- (NSArray *)control:(NSControl *)control textView:(NSTextView *)textView
    completions:(NSArray *)words forPartialWordRange:(NSRange)charRange
    indexOfSelectedItem:(NSInteger *)index
{
  if (control == _labelField || control == _valueField)
    {
      if (control == _valueField && [_fieldName length] == 0)
	return nil;

      NSString *str = [[textView string] substringWithRange:charRange];

      act::database *db = [[self controller] database];

      std::vector<std::string> completions;
      if (control == _labelField)
	{
	  db->complete_field_name([str UTF8String], completions);
	}
      else
	{
	  db->complete_field_value([_fieldName UTF8String],
				   [str UTF8String], completions);
	}

      NSMutableArray *array = [NSMutableArray array];
      for (const auto &it : completions)
	[array addObject:[NSString stringWithUTF8String:it.c_str()]];

      return array;
    }

  return nil;
}

// ActTextFieldDelegate methods

- (ActFieldEditor *)actFieldEditor:(ActTextField *)obj
{
  return [[self controller] fieldEditor];
}

@end
