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

#import "act-activity-list-item.h"

#import "act-config.h"
#import "act-format.h"

#import "ActColor.h"

#define X_INSET_LEFT 16
#define X_INSET_RIGHT 5
#define Y_INSET_TOP 5
#define Y_INSET_BOTTOM 10
#define BODY_RIGHT_INSET 11
#define BODY_MAX_ROWS 4
#define TIME_WIDTH 74
#define STATS_Y_SPACING 2

namespace act {

bool activity_list_item::initialized;
NSDictionary *activity_list_item::title_attrs;
NSDictionary *activity_list_item::body_attrs;
NSDictionary *activity_list_item::time_attrs;
NSDictionary *activity_list_item::stats_attrs;
NSDateFormatter *activity_list_item::time_formatter;

void
activity_list_item::initialize()
{
  NSMutableParagraphStyle *rightStyle
    = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  [rightStyle setAlignment:NSTextAlignmentRight];

  title_attrs = @{
    NSFontAttributeName:
      [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline],
    NSForegroundColorAttributeName: [UIColor blackColor]
  };

  UIColor *gray_color = [UIColor colorWithWhite:.5 alpha:1];

  body_attrs = @{
    NSFontAttributeName:
      [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline],
    NSForegroundColorAttributeName: gray_color
  };

  time_attrs = @{
    NSFontAttributeName:
      [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote],
    NSForegroundColorAttributeName: gray_color,
    NSParagraphStyleAttributeName: rightStyle
  };

  stats_attrs = @{
    NSFontAttributeName:
      [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline],
    NSForegroundColorAttributeName: [UIColor blackColor]
  };

  time_formatter = [[NSDateFormatter alloc] init];
  [time_formatter setDateFormat:
   [NSDateFormatter dateFormatFromTemplate:@"Eha" options:0 locale:nil]];

  initialized = true;
}

activity_list_item::activity_list_item()
: body(nil),
  body_width(0),
  body_height(0),
  valid_height(false)
{
}

activity_list_item::activity_list_item(act::activity_storage_ref storage)
: activity_list_item()
{
  activity.reset(new act::activity(storage));
}

activity_list_item::activity_list_item(const activity_list_item &rhs)
: activity_list_item(rhs.activity->storage())
{
}

namespace {

inline CGFloat
text_attrs_leading(NSDictionary *attrs)
{
  return ((UIFont *)attrs[NSFontAttributeName]).lineHeight;
}

inline CGFloat
text_attrs_ascender(NSDictionary *attrs)
{
  return ((UIFont *)attrs[NSFontAttributeName]).ascender;
}

} // anonymous namespace

void
activity_list_item::draw(const CGRect &bounds)
{
  if (!initialized)
    initialize();

  CGRect itemR = bounds;
  itemR.origin.x += X_INSET_LEFT;
  itemR.origin.y += Y_INSET_TOP;
  itemR.size.width -= X_INSET_LEFT + X_INSET_RIGHT;
  itemR.size.height -= Y_INSET_TOP + Y_INSET_BOTTOM;

  CGRect subR = itemR;

  // draw title and time

  subR.size.height = text_attrs_leading(title_attrs);

  if (1)
    {
      // draw time

      CGRect ssubR = subR;

      ssubR.origin.x += ssubR.size.width - TIME_WIDTH;
      ssubR.origin.y += text_attrs_ascender(title_attrs) - text_attrs_ascender(time_attrs);
      ssubR.size.width = TIME_WIDTH;
      ssubR.size.height = text_attrs_leading(time_attrs);

      [[time_formatter stringFromDate:
	[NSDate dateWithTimeIntervalSince1970:(time_t)activity->date()]]
       drawInRect:ssubR withAttributes:time_attrs];

      // draw title

      ssubR = subR;
      ssubR.origin.x = subR.origin.x;
      ssubR.size.width = subR.size.width - TIME_WIDTH;

      const std::string *s = activity->field_ptr("Course");

      [(s != nullptr
	? [NSString stringWithUTF8String:s->c_str()]
	: @"Untitled")
       drawInRect:ssubR withAttributes:title_attrs];
    }

  subR.origin.y += subR.size.height;

  // draw stats

  std::string buf;
  const char *pending_separator = nullptr;

  if (const std::string *s = activity->field_ptr("Activity"))
    {
      std::string copy(*s);
      copy[0] = toupper(copy[0]);
      buf.append(copy);
      pending_separator = ", ";
    }

  if (activity->distance() != 0)
    {
      // FIXME: use one decimal place and suppress default units?

      if (pending_separator != nullptr)
	buf.append(pending_separator);

      act::format_distance(buf, activity->distance(),
			   activity->distance_unit());
      pending_separator = " ";
    }
  else if (activity->duration() != 0)
    {
      if (pending_separator != nullptr)
	buf.append(pending_separator);

      act::format_duration(buf, activity->duration());
      pending_separator = " ";
    }

  if (const std::string *s = activity->field_ptr("Type"))
    {
      if (pending_separator != nullptr)
	buf.append(pending_separator);

      buf.append(*s);
    }

  subR.size.height = text_attrs_leading(stats_attrs);

  [[NSString stringWithUTF8String:buf.c_str()]
   drawInRect:subR withAttributes:stats_attrs];

  subR.origin.y += subR.size.height + STATS_Y_SPACING;

  // draw body

  subR.size.width -= BODY_RIGHT_INSET;

  update_body_height(subR.size.width);

  if (body)
    {
      subR.size.height = body_height;

      NSInteger opts = (NSStringDrawingTruncatesLastVisibleLine
			| NSStringDrawingUsesLineFragmentOrigin);

      [body drawWithRect:subR options:(NSStringDrawingOptions)opts
       attributes:body_attrs context:nil];
    }
}

void
activity_list_item::update_body()
{
  if (!body)
    {
      const std::string &s = activity->body();

      if (s.size() != 0)
	{
	  NSMutableString *str = [NSMutableString string];

	  const char *ptr = s.c_str();
	  bool finished = false;

	  while (const char *eol = strchr(ptr, '\n'))
	    {
	      NSString *tem = [[NSString alloc] initWithBytes:ptr
			       length:eol-ptr encoding:NSUTF8StringEncoding];
	      [str appendString:tem];
	      ptr = eol + 1;

	      if (eol[1] == '\n')
		{
		  finished = true;
		  break;
		}
	      else if (eol[1] != 0)
		[str appendString:@" "];
	    }

	  if (!finished && *ptr != 0)
	    [str appendString:[NSString stringWithUTF8String:ptr]];

	  body = str;
	}
    }
}

void
activity_list_item::update_body_height(CGFloat width)
{
  width = width - BODY_RIGHT_INSET;

  if (body_width != width)
    {
      CGFloat old_body_height = body_height;

      update_body();

      if (!body)
	body_height = 0;
      else
	{
	  if (!initialized)
	    initialize();

	  /* FIXME: I have no clue why the "+1" is needed here..? */

	  CGSize size = CGSizeMake(width, (BODY_MAX_ROWS+1)
				   * text_attrs_leading(body_attrs));

	  NSInteger opts = (NSStringDrawingTruncatesLastVisibleLine
			    | NSStringDrawingUsesLineFragmentOrigin);

	  CGRect bounds = [body boundingRectWithSize:size
			   options:(NSStringDrawingOptions)opts
			   attributes:body_attrs context:nil];
	  body_height = bounds.size.height;
	}

      body_width = width;

      if (body_height != old_body_height)
	valid_height = false;
    }
}

void
activity_list_item::update_height(CGFloat width)
{
  update_body_height(width - (X_INSET_LEFT + X_INSET_RIGHT));

  if (!valid_height)
    {
      if (!initialized)
	initialize();

      height = 0;
      height += Y_INSET_TOP;
      height += text_attrs_leading(title_attrs);
      height += text_attrs_leading(stats_attrs) + STATS_Y_SPACING;
      height += body_height;
      height += Y_INSET_BOTTOM;
      height = ceil(height);

      valid_height = true;
    }
}

} // namespace act
