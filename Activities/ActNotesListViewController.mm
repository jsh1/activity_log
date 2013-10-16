// -*- c-style: gnu -*-

#import "ActNotesListViewController.h"

#import "ActWindowController.h"

#import "ActFoundationExtensions.h"

#import "act-format.h"

#import <algorithm>

// list view constants
#define Y_OFFSET 8
#define Y_SPACING 10
#define TITLE_HEIGHT 24
#define TITLE_FONT_SIZE 18
#define ITEM_INSET 10
#define TIME_WIDTH 60
#define TIME_HEIGHT TITLE_HEIGHT
#define TIME_FONT_SIZE 12
#define BODY_FONT_SIZE 12
#define BODY_NIL_HEIGHT 9
#define STATS_FONT_SIZE 14
#define STATS_HEIGHT 20
#define DATE_WIDTH 70
#define DAY_OF_WEEK_HEIGHT 20
#define DAY_OF_WEEK_FONT_SIZE 14
#define DAY_OF_MONTH_HEIGHT 36
#define DAY_OF_MONTH_FONT_SIZE 32

// header view constants
#define HEADER_INSET 20
#define MONTH_FONT_SIZE 22
#define MONTH_HEIGHT 26
#define WEEK_FONT_SIZE 16
#define WEEK_HEIGHT 20
#define HEADER_STATS_FONT_SIZE 16
#define HEADER_STATS_WIDTH 200
#define HEADER_STATS_HEIGHT 20

#define DRAW_DATE 1U
#define DRAW_SEPARATOR 2U
#define DRAW_SELECTED 4U
#define DRAW_FOCUSED 8U

@implementation ActNotesListViewController

@synthesize activities = _activities;

+ (NSString *)viewNibName
{
  return @"ActNotesListView";
}

- (void)viewDidLoad
{
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityListDidChange:)
   name:ActActivityListDidChange object:_controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:_controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeField:)
   name:ActActivityDidChangeField object:_controller];
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeBody:)
   name:ActActivityDidChangeBody object:_controller];

  [_listView setPostsBoundsChangedNotifications:YES];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(listBoundsDidChange:)
   name:NSViewBoundsDidChangeNotification object:[_scrollView contentView]];

  _headerItemIndex = 0;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [NSRunLoop cancelPreviousPerformRequestsWithTarget:self];

  [super dealloc];
}

- (NSView *)initialFirstResponder
{
  return _listView;
}

- (NSInteger)rowForActivityStorage:(const act::activity_storage_ref)storage
{
  if (storage == nullptr)
    return NSNotFound;

  for (size_t i = 0; i < _activities.size(); i++)
    {
      if (_activities[i].storage == storage)
	return (NSInteger) i;
    }

  return NSNotFound;
}

- (NSRect)rectForRow:(NSInteger)row
{
  NSRect bounds = [_listView bounds];

  if (NSIsEmptyRect(bounds))
    return bounds;

  CGFloat y = 0;

  for (size_t i = 0; i < _activities.size(); i++)
    {
      if (!(_activities[i].height > 0))
	_activities[i].update_height([_listView bounds].size.width);

      if (i == row)
	{
	  return NSMakeRect(bounds.origin.x,
			    bounds.origin.y + Y_OFFSET + y,
			    bounds.size.width, _activities[i].height);
	}

      y += _activities[i].height;
    }

  return NSZeroRect;
}

- (NSRect)visibleRectForRow:(NSInteger)row
{
  NSRect bounds = [_listView bounds];
  NSRect vis_rect = [_listView visibleRect];

  if (NSIsEmptyRect(vis_rect))
    return vis_rect;

  CGFloat y = 0;

  for (size_t i = 0; i < _activities.size(); i++)
    {
      if (!(y < vis_rect.origin.y + vis_rect.size.height))
	return NSZeroRect;

      if (!(_activities[i].height > 0))
	_activities[i].update_height([_listView bounds].size.width);

      if (i == row)
	{
	  NSRect r = NSMakeRect(bounds.origin.x,
				bounds.origin.y + Y_OFFSET + y,
				bounds.size.width, _activities[i].height);
	  return NSIntersectionRect(r, vis_rect);
	}

      y += _activities[i].height;
    }

  return NSZeroRect;
}

- (NSInteger)rowForYPosition:(CGFloat)p startPosition:(CGFloat *)ret_p
{
  CGFloat y = [_listView bounds].origin.y + Y_OFFSET;

  for (size_t i = 0; i < _activities.size(); i++)
    {
      if (!(_activities[i].height > 0))
	_activities[i].update_height([_listView bounds].size.width);

      CGFloat ny = y + _activities[i].height;

      if (p < ny)
	{
	  if (ret_p != nullptr)
	    *ret_p = y;
	  return i;
	}

      y = ny;
    }

  return NSNotFound;
}

- (void)selectRow:(NSInteger)row
{
  if (row >= 0 && row < _activities.size())
    [_controller setSelectedActivityStorage:_activities[row].storage];
}

- (void)toggleRowSelected:(NSInteger)row
{
  if (row >= 0 && row < _activities.size())
    {
      act::activity_storage_ref sel = [_controller selectedActivityStorage];
      if (_activities[row].storage == sel)
	[_controller setSelectedActivityStorage:nullptr];
      else
	[_controller setSelectedActivityStorage:_activities[row].storage];
    }
}

- (void)updateListViewBounds
{
  CGFloat y = Y_OFFSET;

  for (size_t i = 0; i < _activities.size(); i++)
    {
      if (!(_activities[i].height > 0))
	_activities[i].update_height([_listView bounds].size.width);

      y += _activities[i].height;
    }

  NSRect r = [_listView frame];

  if (r.size.height != y)
    {
      r.size.height = y;
      [_listView setFrame:r];
    }
}

- (void)activityListDidChange:(NSNotification *)note
{
  const std::vector<act::activity_storage_ref> &activities
    = [_controller activityList];

  _activities.clear();

  for (const auto &it : activities)
    _activities.emplace_back(it);

  [self updateListViewBounds];

  [_listView setNeedsDisplay:YES];
  [_headerView setNeedsDisplay:YES];
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  NSInteger row = [self rowForActivityStorage:
		   [_controller selectedActivityStorage]];

  if (row != NSNotFound)
    {
      NSRect r = NSInsetRect([self rectForRow:row], 0, -Y_SPACING*.5);
      [_listView scrollRectToVisible:r];
    }

  [_listView setNeedsDisplay:YES];
}

- (void)activityDidChangeField:(NSNotification *)note
{
  void *ptr = [[[note userInfo] objectForKey:@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);
  NSString *field = [[note userInfo] objectForKey:@"field"];

  NSInteger row = [self rowForActivityStorage:a];
  if (row == NSNotFound)
    return;

  if ([field isEqualToStringNoCase:@"Date"])
    _activities[row].valid_date = false;

  _activities[row].valid_height = false;

  [_listView setNeedsDisplayInRect:[self visibleRectForRow:row]];
}

- (void)activityDidChangeBody:(NSNotification *)note
{
  void *ptr = [[[note userInfo] objectForKey:@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);

  NSInteger row = [self rowForActivityStorage:a];
  if (row == NSNotFound)
    return;

  _activities[row].body.reset();
  _activities[row].body_width = 0;

  [_listView setNeedsDisplayInRect:[self visibleRectForRow:row]];
}

- (void)listBoundsDidChange:(NSNotification *)note
{
  NSView *view = [note object];
  NSInteger idx = [self rowForYPosition:[view bounds].origin.y
		   startPosition:nullptr];

  // FIXME: only if week/month changed?

  if (idx != _headerItemIndex)
    {
      _headerItemIndex = idx;
      [_headerView setNeedsDisplay:YES];
    }
}

- (const ActNotesItem *)headerItem
{
  if (_headerItemIndex >= 0 && _headerItemIndex < _activities.size())
    return &_activities[_headerItemIndex];
  else
    return nullptr;
}

@end

@implementation ActNotesListView

- (void)drawRect:(NSRect)r
{
  NSRect bounds = [self bounds];

  [[NSColor colorWithDeviceWhite:.98 alpha:1] setFill];
  [NSBezierPath fillRect:r];

  CGFloat y = r.origin.y;
  NSInteger row = [_controller rowForYPosition:y startPosition:&y];
  if (row == NSNotFound)
    return;

  const std::vector<ActNotesItem> &activities = [_controller activities];

  act::activity_storage_ref selection = [[_controller controller]
					 selectedActivityStorage];

  for (size_t i = row; y < r.origin.y + r.size.height
       && i < activities.size(); i++)
    {
      activities[i].update_height(bounds.size.width);
      activities[i].update_date();

      NSRect rect;
      rect.origin.x = bounds.origin.x;
      rect.size.width = bounds.size.width;
      rect.origin.y = y;
      rect.size.height = activities[i].height;

      uint32_t flags = 0;
      if (i == 0
	  || !activities[i].date_equal_p(activities[i-1]))
	{
	  flags |= DRAW_DATE;
	}
      if (i < activities.size() - 1
	  && !activities[i].date_equal_p(activities[i+1]))
	{
	  flags |= DRAW_SEPARATOR;
	}
      if (activities[i].storage == selection)
	{
	  flags |= DRAW_SELECTED;
	  if ([[self window] firstResponder] == self)
	    flags |= DRAW_FOCUSED;
	}

      activities[i].draw(rect, flags);

      y += activities[i].height;
    }
}

- (BOOL)isFlipped
{
  return YES;
}

- (BOOL)isOpaque
{
  return YES;
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)becomeFirstResponder
{
  [self setNeedsDisplay:YES];
  return YES;
}

- (BOOL)resignFirstResponder
{
  [self setNeedsDisplay:YES];
  return YES;
}

- (void)keyDown:(NSEvent *)e
{
  switch ([e keyCode])
    {
    case 125:
      [[_controller controller] nextActivity:_controller];
      return;

    case 126:
      [[_controller controller] previousActivity:_controller];
      return;

    case 115:
      [[_controller controller] firstActivity:_controller];
      return;

    case 119:
      [[_controller controller] lastActivity:_controller];
      return;
    }
}

- (void)mouseDown:(NSEvent *)e
{
  NSPoint p = [self convertPoint:[e locationInWindow] fromView:nil];
  NSInteger row = [_controller rowForYPosition:p.y startPosition:nullptr];

  if (row != NSNotFound)
    [_controller toggleRowSelected:row];
}

@end

@implementation ActNotesHeaderView

- (void)drawRect:(NSRect)r
{
  [[NSColor colorWithDeviceWhite:.98 alpha:1] setFill];
  [NSBezierPath fillRect:r];

  if (const ActNotesItem *item = [_controller headerItem])
    item->draw_header([self bounds], 0);
}

- (BOOL)isFlipped
{
  return YES;
}

- (BOOL)isOpaque
{
  return YES;
}

@end


// ActNotesItem implementation

bool ActNotesItem::initialized;
NSDictionary *ActNotesItem::title_attrs;
NSDictionary *ActNotesItem::selected_title_attrs;
NSDictionary *ActNotesItem::body_attrs;
NSDictionary *ActNotesItem::time_attrs;
NSDictionary *ActNotesItem::stats_attrs;
NSDictionary *ActNotesItem::dow_attrs;
NSDictionary *ActNotesItem::dom_attrs;
NSDictionary *ActNotesItem::month_attrs;
NSDictionary *ActNotesItem::week_attrs;
NSColor *ActNotesItem::separator_color;
NSDateFormatter *ActNotesItem::time_formatter;

void
ActNotesItem::initialize()
{
  NSColor *greyColor = [NSColor colorWithDeviceWhite:.2 alpha:1];
  NSColor *redColor = [NSColor colorWithDeviceRed:197/255.
		       green:56/255. blue:51/255. alpha:1];

  NSMutableParagraphStyle *rightStyle
    = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  [rightStyle setAlignment:NSRightTextAlignment];

  NSMutableParagraphStyle *centerStyle
    = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  [centerStyle setAlignment:NSCenterTextAlignment];

  title_attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
		 [NSFont fontWithName:@"Helvetica Neue Bold"
		  size:TITLE_FONT_SIZE], NSFontAttributeName,
		 greyColor, NSForegroundColorAttributeName,
		 nil];
  selected_title_attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
			  [NSFont fontWithName:@"Helvetica Neue Bold"
			   size:TITLE_FONT_SIZE], NSFontAttributeName,
			  [NSColor alternateSelectedControlTextColor],
			  NSForegroundColorAttributeName,
			  nil];
  body_attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
		[NSFont fontWithName:@"Helvetica" size:BODY_FONT_SIZE],
		NSFontAttributeName,
		greyColor, NSForegroundColorAttributeName,
		nil];
  time_attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
		[NSFont fontWithName:@"Helvetica Neue Bold"
		 size:TIME_FONT_SIZE], NSFontAttributeName,
		redColor, NSForegroundColorAttributeName,
		rightStyle, NSParagraphStyleAttributeName,
		nil];
  stats_attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
		 [NSFont fontWithName:@"Helvetica Neue Bold"
		  size:STATS_FONT_SIZE], NSFontAttributeName,
		 redColor, NSForegroundColorAttributeName,
		 nil];
  dow_attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
	       [NSFont fontWithName:@"Helvetica Neue Bold"
		size:DAY_OF_WEEK_FONT_SIZE], NSFontAttributeName,
	       greyColor, NSForegroundColorAttributeName,
	       centerStyle, NSParagraphStyleAttributeName,
	       nil];
  dom_attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
	       [NSFont fontWithName:@"Helvetica Neue Bold"
		size:DAY_OF_MONTH_FONT_SIZE], NSFontAttributeName,
	       greyColor, NSForegroundColorAttributeName,
	       centerStyle, NSParagraphStyleAttributeName,
	       nil];
  month_attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
		 [NSFont fontWithName:@"Helvetica Neue Bold"
		  size:MONTH_FONT_SIZE], NSFontAttributeName,
		 greyColor, NSForegroundColorAttributeName,
		 nil];
  week_attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
		[NSFont fontWithName:@"Helvetica Neue Bold"
		 size:WEEK_FONT_SIZE], NSFontAttributeName,
		greyColor, NSForegroundColorAttributeName,
		nil];

  separator_color = [[NSColor colorWithDeviceWhite:.80 alpha:1] retain];

  time_formatter = [[NSDateFormatter alloc] init];
  [time_formatter setDateStyle:NSDateFormatterNoStyle];
  [time_formatter setTimeStyle:NSDateFormatterShortStyle];

  initialized = true;
}

ActNotesItem::ActNotesItem()
: body_width(0),
  body_height(0),
  valid_date(false),
  valid_height(false)
{
}

ActNotesItem::ActNotesItem(act::activity_storage_ref s)
: ActNotesItem()
{
  storage = s;
}

ActNotesItem::ActNotesItem(const ActNotesItem &rhs)
: ActNotesItem(rhs.storage)
{
}

void
ActNotesItem::draw(const NSRect &bounds, uint32_t flags) const
{
  if (!initialized)
    initialize();

  if (!activity)
    activity.reset(new act::activity(storage));

  update_date();

  if (flags & DRAW_DATE)
    {
      NSRect subR = bounds;
      subR.size.width = std::min(subR.size.width, (CGFloat)DATE_WIDTH);

      subR.origin.y -= 3;

      // draw day-of-month

      subR.size.height = DAY_OF_MONTH_HEIGHT;
      [[NSString stringWithFormat:@"%d", day_of_month]
       drawInRect:subR withAttributes:dom_attrs];

      subR.origin.y += subR.size.height;

      // draw day-of-week

      subR.size.height = DAY_OF_WEEK_HEIGHT;
      [[[[time_formatter shortWeekdaySymbols] objectAtIndex:day_of_week] uppercaseString]
       drawInRect:subR withAttributes:dow_attrs];
    }

  NSRect itemR = bounds;
  itemR.origin.x += DATE_WIDTH;
  itemR.size.width -= (DATE_WIDTH + ITEM_INSET);
  itemR.size.height -= Y_SPACING;

  NSRect subR = itemR;

  // draw title and time

  subR.size.height = TITLE_HEIGHT;

  if (1)
    {
      // draw time

      NSRect ssubR = subR;
      ssubR.origin.x += ssubR.size.width - TIME_WIDTH;
      ssubR.size.width = TIME_WIDTH;

      [[time_formatter stringFromDate:
	[NSDate dateWithTimeIntervalSince1970:(time_t)activity->date()]]
       drawInRect:ssubR withAttributes:time_attrs];

      // draw title

      ssubR.size.width = subR.size.width - TIME_WIDTH;
      ssubR.origin.x = subR.origin.x;

      if (flags & DRAW_SELECTED)
	{
	  if (flags & DRAW_FOCUSED)
	    [[NSColor alternateSelectedControlColor] setFill];
	  else
	    [[NSColor secondarySelectedControlColor] setFill];
	  [NSBezierPath fillRect:NSInsetRect(ssubR, -4, 0)];
	}

      if (const std::string *s = activity->field_ptr("Course"))
	{
	  NSDictionary *attrs = title_attrs;
	  if ((flags & DRAW_SELECTED) && (flags & DRAW_FOCUSED))
	    attrs = selected_title_attrs;

	  [[NSString stringWithUTF8String:s->c_str()]
	   drawInRect:ssubR withAttributes:attrs];
	}
    }

  subR.origin.y += subR.size.height;

  // draw body

  update_body_height(subR.size.width);

  if (body)
    {
      subR.size.height = body_height;

      [body.get() drawInRect:subR withAttributes:body_attrs];
    }

  subR.origin.y += body_height;

  // draw stats

  std::string buf;

  if (activity->distance() != 0)
    {
      // FIXME: use one decimal place and suppress default units?

      act::format_distance(buf, activity->distance(),
			   activity->distance_unit());
      buf.push_back(' ');
    }
  else if (activity->duration() != 0)
    {
      act::format_duration(buf, activity->duration());
      buf.push_back(' ');
    }

  if (const std::string *s = activity->field_ptr("Type"))
    buf.append(*s);

  subR.size.height = STATS_HEIGHT;

  [[NSString stringWithUTF8String:buf.c_str()]
   drawInRect:subR withAttributes:stats_attrs];

  subR.origin.y += subR.size.height;

  subR.origin.y += floor(Y_SPACING * .5);
  subR.size.height = 1;
  if (flags & DRAW_SEPARATOR)
    {
      subR.origin.x = bounds.origin.x;
      subR.size.width = bounds.size.width;
    }
  else
    subR.size.width += ITEM_INSET;

  [separator_color setFill];
  [NSBezierPath fillRect:subR];
  subR.origin.y += 1;
  [[NSColor whiteColor] setFill];
  [NSBezierPath fillRect:subR];
}

void
ActNotesItem::draw_header(const NSRect &bounds, uint32_t flags) const
{
  NSRect subR = NSInsetRect(bounds, HEADER_INSET, 0);
  subR.size.width -= HEADER_STATS_WIDTH;

  update_date();

  subR.size.height = MONTH_HEIGHT;

  [[NSString stringWithFormat:@"%@ %d",
    [[time_formatter monthSymbols] objectAtIndex:month], year]
   drawInRect:subR withAttributes:month_attrs];

  subR.origin.y += subR.size.height;
  subR.size.height = WEEK_HEIGHT;

  [[NSString stringWithFormat:@"Week %d", week + 1]
   drawInRect:subR withAttributes:week_attrs];

  subR.origin.y += subR.size.height;

  subR.origin.x = bounds.origin.x;
  subR.origin.y = bounds.origin.y + bounds.size.height - 2;
  subR.size.width = bounds.size.width;
  subR.size.height = 1;

  [[NSColor whiteColor] setFill];
  [NSBezierPath fillRect:subR];
  subR.origin.y += 1;
  [separator_color setFill];
  [NSBezierPath fillRect:subR];
}

void
ActNotesItem::update_date() const
{
  if (!valid_date)
    {
      if (!activity)
	activity.reset(new act::activity(storage));
      
      time_t date = (time_t) activity->date();

      struct tm tm = {0};
      localtime_r(&date, &tm);

      year = 1900 + tm.tm_year;
      month = tm.tm_mon;
      week = tm.tm_yday / 7;		// FIXME: incorrect
      day_of_week = tm.tm_wday;
      day_of_month = tm.tm_mday;

      valid_date = true;
    }
}

void
ActNotesItem::update_body() const
{
  if (!body)
    {
      if (!activity)
	activity.reset(new act::activity(storage));

      const std::string &s = activity->body();

      if (s.size() != 0)
	{
	  NSMutableString *str = [[NSMutableString alloc] init];

	  const char *ptr = s.c_str();
	  bool finished = false;

	  while (const char *eol = strchr(ptr, '\n'))
	    {
	      NSString *tem = [[NSString alloc] initWithBytes:ptr
			       length:eol-ptr encoding:NSUTF8StringEncoding];
	      [str appendString:tem];
	      [tem release];
	      ptr = eol + 1;
	      if (eol[1] == '\n')
		{
		  [str appendString:@" ..."];
		  finished = true;
		  break;
		}
	      else if (eol[1] != 0)
		[str appendString:@" "];
	    }

	  if (!finished && *ptr != 0)
	    {
	      NSString *tem = [[NSString alloc] initWithUTF8String:ptr];
	      [str appendString:tem];
	      [tem release];
	    }

	  body.reset(str);
	}
    }
}

void
ActNotesItem::update_body_height(CGFloat width) const
{
  if (body_width != width)
    {
      CGFloat old_body_height = body_height;

      update_body();

      if (!body)
	body_height = BODY_NIL_HEIGHT;
      else
	{
	  if (!initialized)
	    initialize();

	  NSSize size = NSMakeSize(width, 100000);

	  NSRect bounds = [body.get() boundingRectWithSize:size
			   options:NSStringDrawingUsesLineFragmentOrigin
			   attributes:body_attrs];
	  body_height = bounds.size.height;
	}

      body_width = width;

      if (body_height != old_body_height)
	valid_height = false;
    }
}

void
ActNotesItem::update_height(CGFloat width) const
{
  update_body_height(width - (DATE_WIDTH + ITEM_INSET));

  if (!valid_height)
    {
      height = TITLE_HEIGHT;
      height += body_height;
      height += STATS_HEIGHT;
      height += Y_SPACING;

      valid_height = true;
    }
}

bool
ActNotesItem::date_equal_p(const ActNotesItem &rhs) const
{
  update_date();
  rhs.update_date();

  return (day_of_month == rhs.day_of_month
	  && month == rhs.month && year == rhs.year);
}
