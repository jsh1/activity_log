// -*- c-style: gnu -*-

#import "ActActivityHeaderFieldView.h"

#import "ActActivityHeaderView.h"
#import "ActActivityView.h"

#import "act-format.h"

#define LABEL_INSET 32
#define LABEL_WIDTH 100
#define LABEL_HEIGHT 14

#define CONTROL_HEIGHT LABEL_HEIGHT

@interface ActActivityHeaderFieldTextView : NSTextView
{
  BOOL _drawsBorder;
}
@end

@implementation ActActivityHeaderFieldView

@synthesize fieldReadOnly = _fieldReadOnly;

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self == nil)
    return nil;

  _labelView = [[ActActivityHeaderFieldTextView alloc] initWithFrame:
		NSMakeRect(0, 0, LABEL_WIDTH, LABEL_HEIGHT)];
  [_labelView setDelegate:self];
  [_labelView setDrawsBackground:NO];
  [_labelView setAlignment:NSRightTextAlignment];
  [self addSubview:_labelView];
  [_labelView release];

  _textView = [[ActActivityHeaderFieldTextView alloc] initWithFrame:
	       NSMakeRect(LABEL_WIDTH, 0, frame.size.width
			  - LABEL_WIDTH, CONTROL_HEIGHT)];
  [_textView setDelegate:self];
  [_textView setDrawsBackground:NO];
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

- (void)setActivityView:(ActActivityView *)view
{
  [super setActivityView:view];

  if (NSFont *font = [view font])
    {
      [_labelView setFont:font];
      [_textView setFont:font];
    }
}

- (NSString *)fieldName
{
  return _fieldName;
}

- (void)_updateFieldName
{
  [_labelView setString:_fieldName];

  const char *field = [_fieldName UTF8String];

  if (const act::activity *a = [[self activityView] activity])
    _fieldReadOnly = a->storage()->field_read_only_p(field);
  else
    _fieldReadOnly = field_read_only_p(act::lookup_field_id(field));

  [_textView setEditable:!_fieldReadOnly];
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
  if (const act::activity *a = [[self activityView] activity])
    {
      const char *field = [_fieldName UTF8String];
      act::field_id field_id = act::lookup_field_id(field);
      act::field_data_type field_type = act::lookup_field_data_type(field_id);

      std::string tem;

      switch (field_type)
	{
	case act::field_data_type::string:
	  if (const std::string *s = a->field_ptr(field))
	    return [NSString stringWithUTF8String:s->c_str()];
	  break;

	case act::field_data_type::keywords:
	  if (const std::vector<std::string>
	      *keys = a->field_keywords_ptr(field_id))
	    {
	      act::format_keywords(tem, *keys);
	    }
	  break;

	default:
	  if (double value = a->field_value(field_id))
	    {
	      act::unit_type unit = a->field_unit(field_id);
	      act::format_value(tem, field_type, value, unit);
	    }
	  break;
	}

      return [NSString stringWithUTF8String:tem.c_str()];
    }

  return @"";
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
  if (act::activity *a = [[self activityView] activity])
    {
      NSTextView *view = [note object];
      NSString *value = [view string];
      std::string str([value UTF8String]);
      std::string field_name([_fieldName UTF8String]);

      // FIXME: undo support

      if (view == _labelView)
	{
	  if (str != field_name)
	    {
	      a->storage()->set_field_name(field_name, str);
	      a->invalidate_cached_values();

	      NSString *oldName = _fieldName;
	      _fieldName = [value copy];
	      [self _updateFieldName];

	      [[self activityView] activityDidChangeField:oldName];
	      [[self activityView] activityDidChangeField:_fieldName];

	      [oldName release];
	    }
	}
      else if (view == _textView)
	{
	  if (![value isEqual:[self fieldString]])
	    {
	      auto id = act::lookup_field_id(field_name.c_str());

	      // FIXME: trim whitespace?

	      if ([value length] != 0)
		{
		  auto type = act::lookup_field_data_type(id);

		  std::string value(str);
		  act::canonicalize_field_string(type, value);

		  (*a->storage())[field_name] = value;
		}
	      else
		a->storage()->delete_field(field_name);

	      a->invalidate_cached_values();

	      [[self activityView] activityDidChangeField:_fieldName];
	    }
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
