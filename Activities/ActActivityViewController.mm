// -*- c-style: gnu -*-

#import "ActActivityViewController.h"

#import "ActActivitySubview.h"
#import "ActWindowController.h"

#import "act-format.h"

#define BODY_WRAP_COLUMN 72

@implementation ActActivityViewController

@synthesize controller = _controller;

- (id)init
{
  self = [super initWithNibName:@"ActActivityView"
	  bundle:[NSBundle mainBundle]];
  if (self == nil)
    return nil;

  _selectedLapIndex = -1;

  return self;
}

- (act::activity_storage_ref)activityStorage
{
  return _activity_storage;
}

- (void)setActivityStorage:(act::activity_storage_ref)storage
{
  if (_activity_storage != storage)
    {
      _activity_storage = storage;
      _activity.reset();

      [self activityDidChange];
    }
}

- (act::activity *)activity
{
  if (!_activity && _activity_storage)
    _activity.reset(new act::activity(_activity_storage));

  return _activity.get();
}

- (NSInteger)selectedLapIndex
{
  return _selectedLapIndex;
}

- (void)setSelectedLapIndex:(NSInteger)idx
{
  if (_selectedLapIndex != idx)
    {
      _selectedLapIndex = idx;

      [self selectedLapDidChange];
    }
}

- (void)activityDidChange
{
  [(NSView *)[self view] activityDidChange];
}

- (void)activityDidChangeField:(NSString *)name
{
  [_controller setNeedsSynchronize:YES];
  [_controller reloadSelectedActivity];

  [(NSView *)[self view] activityDidChangeField:name];
}

- (void)activityDidChangeBody
{
  [_controller setNeedsSynchronize:YES];

  [(NSView *)[self view] activityDidChangeBody];
}

- (void)selectedLapDidChange
{
  [(NSView *)[self view] selectedLapDidChange];
}

- (NSString *)bodyString
{
  if (const act::activity *a = [self activity])
    {
      const std::string &s = a->body();

      if (s.size() != 0)
	{
	  NSMutableString *str = [[NSMutableString alloc] init];

	  const char *ptr = s.c_str();

	  while (const char *eol = strchr(ptr, '\n'))
	    {
	      NSString *tem = [[NSString alloc] initWithBytes:ptr
			       length:eol-ptr encoding:NSUTF8StringEncoding];
	      [str appendString:tem];
	      [tem release];
	      ptr = eol + 1;
	      if (eol[1] == '\n')
		[str appendString:@"\n\n"], ptr++;
	      else if (eol[1] != 0)
		[str appendString:@" "];
	    }

	  if (*ptr != 0)
	    {
	      NSString *tem = [[NSString alloc] initWithUTF8String:ptr];
	      [str appendString:tem];
	      [tem release];
	    }

	  return [str autorelease];
	}
    }

  return @"";
}

- (void)setBodyString:(NSString *)str
{
  static const char whitespace[] = " \t\n\f\r";

  const char *ptr = [str UTF8String];
  ptr = ptr + strspn(ptr, whitespace);

  std::string wrapped;
  size_t column = 0;

  while (*ptr != 0)
    {
      const char *word = ptr + strcspn(ptr, whitespace);

      if (word > ptr)
	{
	  if (column >= BODY_WRAP_COLUMN)
	    {
	      wrapped.push_back('\n');
	      column = 0;
	    }
	  else if (column > 0)
	    {
	      wrapped.push_back(' ');
	      column++;
	    }

	  wrapped.append(ptr, word - ptr);

	  if (word[0] == '\n' && word[1] == '\n')
	    {
	      wrapped.push_back('\n');
	      column = BODY_WRAP_COLUMN;
	    }
	  else
	    column += word - ptr;

	  ptr = word;
	}

      if (ptr[0] != 0)
	ptr++;
    }

  if (column > 0)
    wrapped.push_back('\n');

  if (act::activity *a = [self activity])
    {
      std::string &body = a->storage()->body();

      if (wrapped != body)
	{
	  // FIXME: undo management

	  std::swap(body, wrapped);
	  a->storage()->increment_seed();
	  [self activityDidChangeBody];
	}
    }
}

- (NSString *)stringForField:(NSString *)name
{
  if (const act::activity *a = [self activity])
    {
      const char *field = [name UTF8String];
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

- (void)setString:(NSString *)str forField:(NSString *)name
{
  if (act::activity *a = [self activity])
    {
      auto id = act::lookup_field_id([name UTF8String]);
      const char *field_name = act::canonical_field_name(id);

      // FIXME: trim whitespace?

      if ([str length] != 0)
	{
	  auto type = act::lookup_field_data_type(id);

	  std::string value([str UTF8String]);
	  act::canonicalize_field_string(type, value);

	  (*a->storage())[field_name] = value;
	}
      else
	a->storage()->delete_field(field_name);

      a->storage()->increment_seed();
      a->invalidate_cached_values();

      [self activityDidChangeField:name];
    }
}

- (NSDate *)dateField
{
  if (const act::activity *a = [self activity])
    return [NSDate dateWithTimeIntervalSince1970:a->date()];
  else
    return nil;
}

- (void)setDateField:(NSDate *)date
{
  if (act::activity *a = [self activity])
    {
      if (date != nil)
	{
	  std::string str;
	  act::format_date_time(str, (time_t) [date timeIntervalSince1970]);
	  (*a->storage())["Date"] = str;
	}
      else
	a->storage()->delete_field("Date");

      a->storage()->increment_seed();
      a->invalidate_cached_values();

      [self activityDidChangeField:@"Date"];
    }
}

- (BOOL)isFieldReadOnly:(NSString *)name
{
  const char *field_name = [name UTF8String];

  if (const act::activity *a = [self activity])
    return a->storage()->field_read_only_p(field_name);
  else
    return field_read_only_p(act::lookup_field_id(field_name));
}

// NSSplitViewDelegate methods

- (BOOL)splitView:(NSSplitView *)view canCollapseSubview:(NSView *)subview
{
  return YES;
}

- (BOOL)splitView:(NSSplitView *)view shouldCollapseSubview:(NSView *)subview
    forDoubleClickOnDividerAtIndex:(NSInteger)idx
{
  return [[view subviews] count] <= 2;
}

- (CGFloat)splitView:(NSSplitView *)view constrainMinCoordinate:(CGFloat)p
    ofSubviewAt:(NSInteger)idx
{
  return p + 64;
}

- (CGFloat)splitView:(NSSplitView *)view constrainMaxCoordinate:(CGFloat)p
    ofSubviewAt:(NSInteger)idx
{
  return p - 64;
}

@end
