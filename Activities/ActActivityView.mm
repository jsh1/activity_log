// -*- c-style: gnu -*-

#import "ActActivityView.h"

#import "ActActivityChartView.h"
#import "ActActivityDetailsView.h"
#import "ActActivityMiddleView.h"
#import "ActWindowController.h"

#import "act-format.h"

#define SUBVIEW_Y_SPACING 4

#undef FONT_NAME

#define BODY_WRAP_COLUMN 72

@implementation ActActivityView

static NSArray *_ignoredFields;

+ (void)initialize
{
  if (self == [ActActivityView class])
    {
      _ignoredFields = [[NSArray alloc] initWithObjects:@"GPS-File", nil];
    }
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

- (void)createSubviews
{
  static NSArray *subview_classes;

  if (subview_classes == nil)
    {
      subview_classes = [[NSArray alloc] initWithObjects:
			 [ActActivityDetailsView class],
			 [ActActivityMiddleView class],
			 [ActActivityChartView class],
			 nil];
    }

  _selectedLapIndex = -1;

  for (Class cls in subview_classes)
    {
      if (ActActivitySubview *subview = [cls subviewForView:self])
	[self addSubview:subview];
    }
}

- (void)activityDidChange
{
  BOOL hasSubviews = [[self subviews] count] != 0;

  if (_activity_storage != nullptr && !hasSubviews)
    [self createSubviews];
  else if (_activity_storage == nullptr && hasSubviews)
    [self setSubviews:[NSArray array]];

  for (ActActivitySubview *subview in [self subviews])
    {
#if 0
      if ([subview isKindOfClass:[ActActivityHeaderView class]])
	{
	  ActActivityHeaderView *header = (id) subview;

	  [header setDisplayedFields:
	   [NSArray arrayWithObjects:@"Date", @"Activity", @"Type",
	    @"Course", @"Distance", @"Duration", @"Pace", nil]];

	  if (const act::activity *a = [self activity])
	    {
	      if (const std::string *s = a->field_ptr("activity"))
		{
		  if (strcasecmp(s->c_str(), "run") == 0)
		    [header addDisplayedField:@"VDOT"];
		}
		    
	      if (a->effort() != 0)
		[header addDisplayedField:@"Effort"];
	      if (a->quality() != 0)
		[header addDisplayedField:@"Quality"];
	      if (a->points() != 0)
		[header addDisplayedField:@"Points"];

	      if (a->resting_hr() != 0)
		[header addDisplayedField:@"Resting-HR"];
	      if (a->average_hr() != 0)
		[header addDisplayedField:@"Average-HR"];
	      if (a->max_hr() != 0)
		[header addDisplayedField:@"Max-HR"];
	      if (a->calories() != 0)
		[header addDisplayedField:@"Calories"];

	      if (a->temperature() != 0)
		[header addDisplayedField:@"Temperature"];
	      if (a->dew_point() != 0)
		[header addDisplayedField:@"Dew-Point"];
	      if (a->field_ptr("weather") != nullptr)
		[header addDisplayedField:@"Weather"];

	      if (a->field_ptr("equipment") != nullptr)
		[header addDisplayedField:@"Equipment"];

	      for (const auto &it : *_activity_storage)
		{
		  NSString *str = [[NSString alloc]
				   initWithUTF8String:it.first.c_str()];
		  if (![header displaysField:str]
		      && ![_ignoredFields containsStringNoCase:str])
		    [header addDisplayedField:str];
		  [str release];
		}
	    }
	}
#endif

      [subview activityDidChange];
    }

  [self updateHeight];
}

- (void)activityDidChangeField:(NSString *)name
{
  [_controller setNeedsSynchronize:YES];
  [_controller reloadSelectedActivity];

  for (ActActivitySubview *subview in [self subviews])
    [subview activityDidChangeField:name];
}

- (void)activityDidChangeBody
{
  [_controller setNeedsSynchronize:YES];

  for (ActActivitySubview *subview in [self subviews])
    [subview activityDidChangeBody];
}

- (void)selectedLapDidChange
{
  for (ActActivitySubview *subview in [self subviews])
    {
      [subview selectedLapDidChange];
    }
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
      const char *field_name = [name UTF8String];

      auto id = act::lookup_field_id(field_name);

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

- (BOOL)isFieldReadOnly:(NSString *)name
{
  const char *field_name = [name UTF8String];

  if (const act::activity *a = [self activity])
    return a->storage()->field_read_only_p(field_name);
  else
    return field_read_only_p(act::lookup_field_id(field_name));
}

- (void)updateHeight
{
  NSRect rect = [self frame];
  CGFloat height = [self preferredHeightForWidth:rect.size.width];

  if (rect.size.height != height)
    {
      rect.size.height = height;
      [self setFrame:rect];
    }

  [self layoutSubviews];
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
  CGFloat y = 0;

  for (ActActivitySubview *subview in [self subviews])
    {
      NSEdgeInsets insets = [subview edgeInsets];

      CGFloat sub_width = width - (insets.left + insets.right);
      CGFloat sub_height = [subview preferredHeightForWidth:sub_width];

      if (sub_width > 0 && sub_height > 0)
	y = y + insets.top + sub_height + insets.bottom + SUBVIEW_Y_SPACING;
    }

  return y;
}

- (void)layoutSubviews
{
  NSRect bounds = [self bounds];
  CGFloat x = bounds.origin.x;
  CGFloat y = bounds.origin.y;
  CGFloat width = bounds.size.width;

  for (ActActivitySubview *subview in [self subviews])
    {
      NSEdgeInsets insets = [subview edgeInsets];

      CGFloat sub_width = width - (insets.left + insets.right);
      CGFloat sub_height = [subview preferredHeightForWidth:sub_width];

      if (sub_width > 0 && sub_height > 0)
	{
	  NSRect frame = NSMakeRect(x + insets.left, y + insets.top,
				    sub_width, sub_height);

	  [subview setHidden:NO];
	  [subview setFrame:frame];
	  [subview layoutSubviews];

	  y = y + insets.top + sub_height + insets.bottom + SUBVIEW_Y_SPACING;
	}
      else
	[subview setHidden:YES];
    }
}

- (NSFont *)font
{
  static NSFont *font;

  if (font == nil)
    {
      CGFloat fontSize = [NSFont smallSystemFontSize];
#ifdef FONT_NAME
      font = [NSFont fontWithName:@FONT_NAME size:fontSize];
#endif
      if (font == nil)
	font = [NSFont systemFontOfSize:fontSize];
    }

  return font;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
  [super resizeSubviewsWithOldSize:oldSize];

  NSSize newSize = [self bounds].size;

  if (newSize.width != oldSize.width)
    [self updateHeight];
}

- (BOOL)isFlipped
{
  return YES;
}

@end
