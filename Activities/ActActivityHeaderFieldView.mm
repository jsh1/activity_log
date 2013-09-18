// -*- c-style: gnu -*-

#import "ActActivityHeaderFieldView.h"

#import "ActActivityHeaderView.h"
#import "ActActivityViewController.h"

#define LABEL_INSET 0
#define LABEL_WIDTH 100
#define LABEL_HEIGHT 14

#define CONTROL_HEIGHT LABEL_HEIGHT

@interface ActActivityHeaderFieldTextView : NSTextView
{
  BOOL _drawsBorder;
}
@end

@implementation ActActivityHeaderFieldView

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self == nil)
    return nil;

  NSFont *font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];

  _labelView = [[ActActivityHeaderFieldTextView alloc] initWithFrame:
		NSMakeRect(0, 0, LABEL_WIDTH, LABEL_HEIGHT)];
  [_labelView setDelegate:self];
  [_labelView setDrawsBackground:NO];
  [_labelView setAlignment:NSRightTextAlignment];
  [_labelView setFont:font];
  [_labelView setTextColor:[NSColor colorWithDeviceWhite:.4 alpha:1]];
  [self addSubview:_labelView];
  [_labelView release];

  _textView = [[ActActivityHeaderFieldTextView alloc] initWithFrame:
	       NSMakeRect(LABEL_WIDTH, 0, frame.size.width
			  - LABEL_WIDTH, CONTROL_HEIGHT)];
  [_textView setDelegate:self];
  [_textView setDrawsBackground:NO];
  [_textView setFont:font];
  [_textView setTextColor:[NSColor colorWithDeviceWhite:.1 alpha:1]];
  [self addSubview:_textView];
  [_textView release];

  return self;
}

- (void)dealloc
{
  [_labelView setDelegate:nil];
  [_textView setDelegate:nil];

  [_fieldName release];

  [super dealloc];
}

- (NSString *)fieldName
{
  return _fieldName;
}

- (void)_updateFieldName
{
  [_labelView setString:_fieldName];

  [_textView setEditable:![[self controller] isFieldReadOnly:_fieldName]];
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
  return [[self controller] stringForField:_fieldName];
}

- (void)setFieldString:(NSString *)str
{
  ActActivityViewController *controller = [self controller];

  if (![str isEqual:[controller stringForField:_fieldName]])
    {
      [controller setString:str forField:_fieldName];
    }
}

- (void)activityDidChange
{
  [self _updateFieldName];
  [_textView setString:[self fieldString]];
}

- (void)activityDidChangeField:(NSString *)name
{
  // reload everything in case of dependent fields (pace, etc)

  [self _updateFieldName];
  [_textView setString:[self fieldString]];
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
  return CONTROL_HEIGHT;
}

- (void)layoutSubviews
{
  NSRect bounds = [self bounds];
  NSRect frame = bounds;

  frame.size.width = LABEL_WIDTH;
  [_labelView setFrame:frame];

  frame.origin.x += frame.size.width;
  frame.size.width = bounds.size.width - frame.size.width - LABEL_INSET;
  [_textView setFrame:frame];
}

// NSTextViewDelegate methods

- (void)textDidEndEditing:(NSNotification *)note
{
  if (act::activity *a = [[self controller] activity])
    {
      NSTextView *view = [note object];
      NSString *value = [view string];

      // FIXME: undo support

      if (view == _labelView)
	{
	  std::string str([value UTF8String]);
	  std::string field_name([_fieldName UTF8String]);

	  if (str != field_name)
	    {
	      a->storage()->set_field_name(field_name, str);
	      a->storage()->increment_seed();
	      a->invalidate_cached_values();

	      NSString *oldName = _fieldName;
	      _fieldName = [value copy];
	      [self _updateFieldName];

	      [[self controller] activityDidChangeField:oldName];
	      [[self controller] activityDidChangeField:_fieldName];

	      [oldName release];
	    }
	}
      else if (view == _textView)
	{
	  [self setFieldString:value];
	}
    }
}

@end

@implementation ActActivityHeaderFieldTextView

- (BOOL)becomeFirstResponder
{
  if (![super becomeFirstResponder])
    return NO;

  _drawsBorder = YES;
  [self setNeedsDisplay:YES];

  return YES;
}

- (BOOL)resignFirstResponder
{
  if (![super resignFirstResponder])
    return NO;

  _drawsBorder = NO;
  [self setNeedsDisplay:YES];

  return YES;
}

- (void)drawRect:(NSRect)r
{
  if (_drawsBorder)
    {
      if ([self isEditable])
	[[NSColor keyboardFocusIndicatorColor] setStroke];
      else
	[[NSColor secondarySelectedControlColor] setStroke];

      [NSBezierPath strokeRect:NSInsetRect([self bounds], .5, .5)];
    }

  [super drawRect:r];
}

- (void)keyDown:(NSEvent *)e
{
  unsigned int keyCode = [e keyCode];

  if (keyCode == 125 /* Down */ || keyCode == 126 /* Up */
      || keyCode == 36 /* RET */ || keyCode == 48 /* TAB */)
    {
      if ([[self window] firstResponder] == self)
	{
	  if (keyCode == 48 /* TAB */)
	    {
	      if (!([e modifierFlags] & NSShiftKeyMask))
		[[self window] selectNextKeyView:self];
	      else
		[[self window] selectPreviousKeyView:self];
	    }
	  else
	    {
	      BOOL backwards = keyCode == 126;

	      ActActivityHeaderFieldView *field = (id) [self superview];
	      ActActivityHeaderView *header = (id) [field superview];

	      NSInteger item_idx
	        = [[field subviews] indexOfObjectIdenticalTo:self];
	      NSInteger field_idx
	        = [[header subviews] indexOfObjectIdenticalTo:field];

	      if (!backwards)
		{
		  if (field_idx + 1 < [[header subviews] count])
		    field_idx += 1;
		  else
		    field_idx = 0;
		}
	      else
		{
		  if (field_idx - 1 >= 0)
		    field_idx -= 1;
		  else
		    field_idx = [[header subviews] count] - 1;
		}

	      field = [[header subviews] objectAtIndex:field_idx];
	      NSView *item = [[field subviews] objectAtIndex:item_idx];

	      [[self window] makeFirstResponder:item];
	    }
	}
    }
  else
    {
      [super keyDown:e];
    }
}

@end
