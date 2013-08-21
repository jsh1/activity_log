// -*- c-style: gnu -*-

#import "ActActivityHeaderFieldView.h"

#import "ActActivityView.h"

#import "act-format.h"

#define LABEL_WIDTH 100
#define LABEL_HEIGHT 14

#define CONTROL_HEIGHT LABEL_HEIGHT

@implementation ActActivityHeaderFieldView

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self == nil)
    return nil;

  _labelView = [[NSTextField alloc] initWithFrame:
		NSMakeRect(0, 0, LABEL_WIDTH, LABEL_HEIGHT)];
  [_labelView setDrawsBackground:NO];
  [_labelView setBordered:NO];
  [_labelView setBezeled:NO];
  [_labelView setEditable:NO];
  [_labelView setAlignment:NSRightTextAlignment];
  [[_labelView cell] setControlSize:NSSmallControlSize];
  [[_labelView cell] setFont:
   [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
  [self addSubview:_labelView];
  [_labelView release];

  _textView = [[NSTextView alloc] initWithFrame:
	       NSMakeRect(LABEL_WIDTH, 0, frame.size.width
			  - LABEL_WIDTH, CONTROL_HEIGHT)];
  [_textView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
  [self addSubview:_textView];
  [_textView release];
  [_textView setDrawsBackground:NO];

  return self;
}

- (void)dealloc
{
  [_fieldName release];

  [super dealloc];
}

- (NSString *)fieldName
{
  return _fieldName;
}

- (void)setFieldName:(NSString *)name
{
  if (_fieldName != name)
    {
      [_fieldName release];
      _fieldName = [name copy];

      [_labelView setStringValue:[_fieldName stringByAppendingString:@": "]];
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
	case act::type_string:
	  if (const std::string *s = a->field_ptr(field))
	    return [NSString stringWithUTF8String:s->c_str()];
	  break;

	case act::type_keywords:
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

- (void)setFieldString:(NSString *)str
{
  // FIXME: implement this
}

- (void)activityDidChange
{
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
  frame.size.width = bounds.size.width - frame.size.width;
  [_textView setFrame:frame];
}

@end
