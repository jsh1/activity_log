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

#import "ActNotesListViewController.h"

#import "ActAppDelegate.h"
#import "ActColor.h"
#import "ActFont.h"
#import "ActWindowController.h"

#import "act-config.h"
#import "act-format.h"
#import "act-util.h"

#import "AppKitExtensions.h"
#import "FoundationExtensions.h"

#import <algorithm>
#import <memory>

// list view constants
#define Y_OFFSET 8
#define Y_SPACING 10
#define TITLE_HEIGHT 24
#define TITLE_FONT_SIZE 18
#define TITLE_LEADING 22
#define ITEM_INSET 10
#define TIME_WIDTH 60
#define TIME_HEIGHT TITLE_HEIGHT
#define TIME_FONT_SIZE 12
#define BODY_FONT_SIZE 12
#define BODY_NIL_HEIGHT 9
#define STATS_FONT_SIZE 14
#define STATS_HEIGHT 25
#define STATS_LEADING 23
#define DATE_WIDTH 70
#define DAY_OF_WEEK_HEIGHT 20
#define DAY_OF_WEEK_FONT_SIZE 14
#define DAY_OF_MONTH_HEIGHT 36
#define DAY_OF_MONTH_FONT_SIZE 32

// header view constants
#define HEADER_LEFT_INSET 20
#define HEADER_RIGHT_INSET 10
#define MONTH_FONT_SIZE 22
#define MONTH_HEIGHT 26
#define WEEK_FONT_SIZE 15
#define WEEK_HEIGHT 24
#define HEADER_STATS_FONT_SIZE 14
#define HEADER_STATS_WIDTH 100
#define HEADER_STATS_HEIGHT 24

#define DRAW_DATE 1U
#define DRAW_SEPARATOR 2U
#define DRAW_SELECTED 4U
#define DRAW_FOCUSED 8U

struct ActNotesItem
{
  act::activity_storage_ref storage;

  mutable std::unique_ptr<act::activity> activity;

  mutable time_t date;
  mutable int year;
  mutable int month;
  mutable int week;
  mutable int day_of_week;
  mutable int day_of_month;

  mutable objc_ptr<NSString> body;

  mutable CGFloat body_width;
  mutable CGFloat body_height;
  mutable CGFloat height;

  mutable bool valid_date :1;
  mutable bool valid_height :1;

  ActNotesItem();
  explicit ActNotesItem(act::activity_storage_ref storage);
  explicit ActNotesItem(const ActNotesItem &rhs);

  struct header_stats
    {
      double month_distance;
      double week_distance;
    };

  void draw(const NSRect &bounds, uint32_t flags) const;
  void draw_header(const NSRect &bounds, uint32_t flags,
    const header_stats &stats) const;

  void update_date() const;
  void update_body() const;
  void update_body_height(CGFloat width) const;
  void update_height(CGFloat width) const;

  double distance() const;
  double duration() const;
  double points() const;

  bool same_day_p(const ActNotesItem &other) const;

private:
  static bool initialized;
  static NSDictionary *title_attrs;
  static NSDictionary *selected_title_attrs;
  static NSDictionary *body_attrs;
  static NSDictionary *time_attrs;
  static NSDictionary *stats_attrs;
  static NSDictionary *dow_attrs;
  static NSDictionary *dom_attrs;
  static NSDictionary *month_attrs;
  static NSDictionary *week_attrs;
  static NSDictionary *header_stats_attrs;
  static NSColor *separator_color;
  static NSDateFormatter *time_formatter;
  static NSDateFormatter *week_formatter;
  static NSDateFormatter *month_formatter;

  static void initialize();
};

@interface ActNotesListViewController ()
@property(nonatomic, readonly) const std::vector<ActNotesItem> &activities;
@end

@implementation ActNotesListViewController
{
  std::vector<ActNotesItem> _activities;

  NSInteger _headerItemIndex;
  struct ActNotesItem::header_stats _headerStats;
}

@synthesize scrollView = _scrollView;
@synthesize listView = _listView;
@synthesize headerView = _headerView;
@synthesize activities = _activities;

+ (NSString *)viewNibName
{
  return @"ActNotesListView";
}

- (void)viewDidLoad
{
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityListDidChange:)
   name:ActActivityListDidChange object:self.controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:self.controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeField:)
   name:ActActivityDidChangeField object:self.controller];
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeBody:)
   name:ActActivityDidChangeBody object:self.controller];

  [_listView setPostsBoundsChangedNotifications:YES];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(listBoundsDidChange:)
   name:NSViewBoundsDidChangeNotification object:_scrollView.contentView];

  _headerItemIndex = -1;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [NSRunLoop cancelPreviousPerformRequestsWithTarget:self];

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
  NSRect bounds = _listView.bounds;

  if (NSIsEmptyRect(bounds))
    return bounds;

  CGFloat y = 0;

  for (size_t i = 0; i < _activities.size(); i++)
    {
      _activities[i].update_height(_listView.bounds.size.width);

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
  NSRect bounds = _listView.bounds;
  NSRect vis_rect = _listView.visibleRect;

  if (NSIsEmptyRect(vis_rect))
    return vis_rect;

  CGFloat y = 0;

  for (size_t i = 0; i < _activities.size(); i++)
    {
      if (!(y < vis_rect.origin.y + vis_rect.size.height))
	return NSZeroRect;

      _activities[i].update_height(_listView.bounds.size.width);

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
  CGFloat y = _listView.bounds.origin.y + Y_OFFSET;

  for (size_t i = 0; i < _activities.size(); i++)
    {
      _activities[i].update_height(_listView.bounds.size.width);
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
    self.controller.selectedActivityStorage = _activities[row].storage;
}

- (void)toggleRowSelected:(NSInteger)row
{
  if (row >= 0 && row < _activities.size())
    {
      act::activity_storage_ref sel = self.controller.selectedActivityStorage;
      if (_activities[row].storage == sel)
	self.controller.selectedActivityStorage = nullptr;
      else
	self.controller.selectedActivityStorage = _activities[row].storage;
    }
}

- (void)updateListViewBounds
{
  CGFloat y = Y_OFFSET;

  // FIXME: calculating the height of all items is expensive, and
  // unnecessary if we're only displaying the first page. One fix
  // could be to not add all items to _activities, only those that
  // may be visible, and add more as the view scrolls.

  for (size_t i = 0; i < _activities.size(); i++)
    {
      _activities[i].update_height(_listView.bounds.size.width);
      y += _activities[i].height;
    }

  NSRect r = _listView.frame;

  if (r.size.height != y)
    {
      r.size.height = y;
      _listView.frame = r;
    }
}

- (void)updateHeaderItemIndex
{
  NSInteger idx = [self rowForYPosition:_scrollView.contentView.bounds.origin.y
		   startPosition:nullptr];

  // FIXME: only if week/month changed?

  if (idx != _headerItemIndex)
    {
      if (idx >= 0 && idx < _activities.size())
	{
	  const ActNotesItem &item = _activities[idx];

	  item.update_date();

	  _headerStats.month_distance
	    = _headerStats.week_distance = item.distance();

	  for (ssize_t i = idx-1; i >= 0; i--)
	    {
	      const ActNotesItem &it = _activities[i];
	      it.update_date();
	      if (it.month != item.month && it.week != item.week)
		break;
	      double dist = it.distance();
	      if (it.month == item.month)
		_headerStats.month_distance += dist;
	      if (it.week == item.week)
		_headerStats.week_distance += dist;
	    }

	  for (size_t i = idx+1; i < _activities.size(); i++)
	    {
	      const ActNotesItem &it = _activities[i];
	      it.update_date();
	      if (it.month != item.month && it.week != item.week)
		break;
	      double dist = it.distance();
	      if (it.month == item.month)
		_headerStats.month_distance += dist;
	      if (it.week == item.week)
		_headerStats.week_distance += dist;
	    }
	}

      _headerItemIndex = idx;
      _headerView.needsDisplay = YES;
    }
}

- (void)activityListDidChange:(NSNotification *)note
{
  const auto &activities = self.controller.activityList;

  _activities.clear();

  for (const auto &it : activities)
    _activities.emplace_back(it.storage());

  [self updateListViewBounds];
  [self updateHeaderItemIndex];

  _listView.needsDisplay = YES;
  _headerView.needsDisplay = YES;
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  NSInteger row = [self rowForActivityStorage:
		   self.controller.selectedActivityStorage];

  if (row != NSNotFound)
    {
      NSRect r = NSInsetRect([self rectForRow:row], 0, -Y_SPACING*.5);
      [_listView scrollRectToVisible:r];
    }

  _listView.needsDisplay = YES;
}

- (void)activityDidChangeField:(NSNotification *)note
{
  void *ptr = [note.userInfo[@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);
  NSString *field = note.userInfo[@"field"];

  NSInteger row = [self rowForActivityStorage:a];
  if (row == NSNotFound)
    return;

  if ([field isEqualToString:@"Date" caseInsensitive:YES])
    _activities[row].valid_date = false;

  _activities[row].valid_height = false;

  [_listView setNeedsDisplayInRect:[self visibleRectForRow:row]];
}

- (void)activityDidChangeBody:(NSNotification *)note
{
  void *ptr = [note.userInfo[@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);

  NSInteger row = [self rowForActivityStorage:a];
  if (row == NSNotFound)
    return;

  _activities[row].body.reset();
  _activities[row].body_width = 0;

  // FIXME: a bit heavy-handed. Ideally find the index of the last
  // visible item, and if 'row' is not greater than that, invalidate
  // the view.

  _listView.needsDisplay = YES;
}

- (void)listBoundsDidChange:(NSNotification *)note
{
  [self updateHeaderItemIndex];
}

- (const ActNotesItem *)headerItem
{
  if (_headerItemIndex >= 0 && _headerItemIndex < _activities.size())
    return &_activities[_headerItemIndex];
  else
    return nullptr;
}

- (const ActNotesItem::header_stats &)headerStats
{
  return _headerStats;
}

@end

@implementation ActNotesListView

@synthesize controller = _controller;

- (void)drawRect:(NSRect)r
{
  NSRect bounds = self.bounds;

  [[ActColor controlBackgroundColor] setFill];
  [NSBezierPath fillRect:r];

  CGFloat y = r.origin.y;
  NSInteger row = [_controller rowForYPosition:y startPosition:&y];
  if (row == NSNotFound)
    return;

  const std::vector<ActNotesItem> &activities = _controller.activities;

  act::activity_storage_ref selection
    = _controller.controller.selectedActivityStorage;

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
	  || !activities[i].same_day_p(activities[i-1]))
	{
	  flags |= DRAW_DATE;
	}
      if (i == activities.size() - 1
	  || !activities[i].same_day_p(activities[i+1]))
	{
	  flags |= DRAW_SEPARATOR;
	}
      if (activities[i].storage == selection)
	{
	  flags |= DRAW_SELECTED;
	  if (self.window.firstResponder == self)
	    flags |= DRAW_FOCUSED;
	}

      activities[i].draw(rect, flags);

      y += activities[i].height;
    }
}

- (void)scrollPageUpAnimated:(BOOL)flag
{
  NSRect rect = self.visibleRect;
  rect.origin.y -= rect.size.height;
  [self scrollRectToVisible:rect animated:flag];
}

- (void)scrollPageDownAnimated:(BOOL)flag
{
  NSRect rect = self.visibleRect;
  rect.origin.y += rect.size.height;
  [self scrollRectToVisible:rect animated:flag];
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
  self.needsDisplay = YES;
  return YES;
}

- (BOOL)resignFirstResponder
{
  self.needsDisplay = YES;
  return YES;
}

- (void)keyDown:(NSEvent *)e
{
  NSString *chars = e.charactersIgnoringModifiers;

  if (chars.length == 1)
    {
      ActWindowController *controller = _controller.controller;

      switch ([chars characterAtIndex:0])
	{
	case NSDownArrowFunctionKey:
	  [controller nextActivity:_controller];
	  return;

	case NSUpArrowFunctionKey:
	  [controller previousActivity:_controller];
	  return;

	case NSHomeFunctionKey:
	  [controller firstActivity:_controller];
	  return;

	case NSEndFunctionKey:
	  [controller lastActivity:_controller];
	  return;

	case NSPageUpFunctionKey:
	  [self scrollPageUpAnimated:NO];
	  [self flashScrollersIfNeeded];
	  return;

	case NSPageDownFunctionKey:
	  [self scrollPageDownAnimated:NO];
	  [self flashScrollersIfNeeded];
	  return;
	}
    }

  [super keyDown:e];
}

- (void)mouseDown:(NSEvent *)e
{
  NSPoint p = [self convertPoint:e.locationInWindow fromView:nil];
  NSInteger row = [_controller rowForYPosition:p.y startPosition:nullptr];

  if (row != NSNotFound)
    [_controller toggleRowSelected:row];
}

@end

@implementation ActNotesHeaderView

@synthesize controller = _controller;

- (void)drawRect:(NSRect)r
{
  if (const ActNotesItem *item = _controller.headerItem)
    item->draw_header(self.bounds, 0, _controller.headerStats);
}

- (BOOL)isFlipped
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
NSDictionary *ActNotesItem::header_stats_attrs;
NSColor *ActNotesItem::separator_color;
NSDateFormatter *ActNotesItem::time_formatter;
NSDateFormatter *ActNotesItem::week_formatter;
NSDateFormatter *ActNotesItem::month_formatter;

void
ActNotesItem::initialize()
{
  NSColor *greyColor = [ActColor controlTextColor];
  NSColor *redColor = [ActColor controlDetailTextColor];
  NSColor *blueColor = [ActColor colorWithCalibratedRed:72/255. green:122/255. blue:1 alpha:1];

  NSMutableParagraphStyle *rightStyle
    = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  rightStyle.alignment = NSRightTextAlignment;

  NSMutableParagraphStyle *centerStyle
    = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  centerStyle.alignment = NSCenterTextAlignment;

  title_attrs = @{
    NSFontAttributeName: [NSFont boldSystemFontOfSize:TITLE_FONT_SIZE],
    NSForegroundColorAttributeName: greyColor,
  };

  selected_title_attrs = @{
    NSFontAttributeName: [NSFont boldSystemFontOfSize:TITLE_FONT_SIZE],
    NSForegroundColorAttributeName: [ActColor alternateSelectedControlTextColor],
  };

  body_attrs = @{
    NSFontAttributeName: [ActFont bodyFontOfSize:BODY_FONT_SIZE],
    NSForegroundColorAttributeName: greyColor
  };

  time_attrs = @{
    NSFontAttributeName: [NSFont systemFontOfSize:TIME_FONT_SIZE],
    NSForegroundColorAttributeName: blueColor,
    NSParagraphStyleAttributeName: rightStyle,
  };

  stats_attrs = @{
    NSFontAttributeName: [NSFont boldSystemFontOfSize:STATS_FONT_SIZE],
    NSForegroundColorAttributeName: redColor,
  };

  dow_attrs = @{
    NSFontAttributeName: [NSFont boldSystemFontOfSize:DAY_OF_WEEK_FONT_SIZE],
    NSForegroundColorAttributeName: greyColor,
    NSParagraphStyleAttributeName: centerStyle,
  };

  dom_attrs = @{
    NSFontAttributeName: [ActFont mediumSystemFontOfSize:DAY_OF_MONTH_FONT_SIZE],
    NSForegroundColorAttributeName: greyColor,
    NSParagraphStyleAttributeName: centerStyle,
  };

  month_attrs = @{
    NSFontAttributeName: [NSFont boldSystemFontOfSize:MONTH_FONT_SIZE],
    NSForegroundColorAttributeName: greyColor,
  };

  week_attrs = @{
    NSFontAttributeName: [NSFont boldSystemFontOfSize:WEEK_FONT_SIZE],
    NSForegroundColorAttributeName: greyColor,
  };

  header_stats_attrs = @{
    NSFontAttributeName: [NSFont boldSystemFontOfSize:HEADER_STATS_FONT_SIZE],
    NSForegroundColorAttributeName: redColor,
    NSParagraphStyleAttributeName: rightStyle,
  };

  separator_color = [NSColor colorWithDeviceWhite:.85 alpha:1];

  NSLocale *locale = ((ActAppDelegate *)[NSApp delegate]).currentLocale;

  time_formatter = [[NSDateFormatter alloc] init];
  time_formatter.locale = locale;
  time_formatter.dateFormat =
   [NSDateFormatter dateFormatFromTemplate:@"ha" options:0 locale:locale];

  week_formatter = [[NSDateFormatter alloc] init];
  week_formatter.locale = locale;
  week_formatter.dateFormat =
   [NSDateFormatter dateFormatFromTemplate:@"MMMdd" options:0 locale:locale];

  month_formatter = [[NSDateFormatter alloc] init];
  month_formatter.locale = locale;
  month_formatter.dateFormat =
   [NSDateFormatter dateFormatFromTemplate:@"MMMMyyyy" options:0 locale:locale];

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
      [((NSString *)time_formatter.shortWeekdaySymbols[day_of_week]).uppercaseString
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
	    [[ActColor alternateSelectedControlColor] setFill];
	  else
	    [[ActColor secondarySelectedControlColor] setFill];
	  [NSBezierPath fillRect:NSInsetRect(ssubR, -4, 0)];
	}

      const std::string *s = activity->field_ptr("Course");

      NSDictionary *attrs = title_attrs;
      if ((flags & DRAW_SELECTED) && (flags & DRAW_FOCUSED))
	attrs = selected_title_attrs;

      [(s != nullptr ? @(s->c_str()) : @"Untitled")
       drawInRect:ssubR withAttributes:attrs];
    }

  subR.origin.y += TITLE_LEADING;

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

  [@(buf.c_str()) drawInRect:subR withAttributes:stats_attrs];

  subR.origin.y += STATS_LEADING;

  // draw body

  update_body_height(subR.size.width);

  if (body)
    {
      subR.size.height = body_height;

      [body.get() drawInRect:subR withAttributes:body_attrs];
    }

  subR.origin.y += body_height;

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
}

void
ActNotesItem::draw_header(const NSRect &bounds, uint32_t flags,
			  const header_stats &stats) const
{
  NSRect subR = bounds;
  subR.origin.x += HEADER_LEFT_INSET;
  subR.size.width -= HEADER_LEFT_INSET + HEADER_RIGHT_INSET;
  subR.size.width -= HEADER_STATS_WIDTH;

  update_date();

  // draw month name

  subR.size.height = MONTH_HEIGHT;

  [[month_formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:date]]
   drawInRect:subR withAttributes:month_attrs];

  // draw week index

  subR.origin.y += subR.size.height;
  subR.size.height = WEEK_HEIGHT;

  {
    static NSString *en_dash;
    if (en_dash == nil)
      {
	unichar c = 0x2013;
	en_dash = [[NSString alloc] initWithCharacters:&c length:1];
      }

    time_t start_date = act::week_date(week);
    time_t end_date = start_date + 6 * 24 * 60 * 60;

    [[NSString stringWithFormat:@"%@ %@ %@",
      [week_formatter stringFromDate:
       [NSDate dateWithTimeIntervalSince1970:start_date]],
      en_dash,
      [week_formatter stringFromDate:
       [NSDate dateWithTimeIntervalSince1970:end_date]]]
     drawInRect:subR withAttributes:week_attrs];
  }

  // draw month stats

  subR.origin.x += subR.size.width;
  subR.origin.y = bounds.origin.y + (MONTH_HEIGHT - HEADER_STATS_HEIGHT) + 3;
  subR.size.width = HEADER_STATS_WIDTH;
  subR.size.height = HEADER_STATS_HEIGHT;

  if (stats.month_distance != 0)
    {
      std::string buf;
      act::format_distance(buf, stats.month_distance, act::unit_type::unknown);
      [@(buf.c_str()) drawInRect:subR withAttributes:header_stats_attrs];
    }

  // draw week stats

  subR.origin.y += subR.size.height + (WEEK_HEIGHT - HEADER_STATS_HEIGHT) - 1;

  if (stats.week_distance != 0)
    {
      std::string buf;
      act::format_distance(buf, stats.week_distance, act::unit_type::unknown);
      [@(buf.c_str()) drawInRect:subR withAttributes:header_stats_attrs];
    }

  // draw separator

  subR.origin.x = bounds.origin.x;
  subR.origin.y = bounds.origin.y + bounds.size.height - 1;
  subR.size.width = bounds.size.width;
  subR.size.height = 1;

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
      
      date = (time_t) activity->date();

      struct tm tm = {0};
      localtime_r(&date, &tm);

      year = 1900 + tm.tm_year;
      month = tm.tm_mon;
      week = act::week_index(date);
      day_of_week = tm.tm_wday;
      day_of_month = tm.tm_mday;

      valid_date = true;
    }
}

double
ActNotesItem::distance() const
{
  if (!activity)
    activity.reset(new act::activity(storage));

  return activity->distance();
}

double
ActNotesItem::duration() const
{
  if (!activity)
    activity.reset(new act::activity(storage));

  return activity->duration();
}

double
ActNotesItem::points() const
{
  if (!activity)
    activity.reset(new act::activity(storage));

  return activity->points();
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
      height = TITLE_LEADING;
      height += STATS_LEADING;
      height += body_height;
      height += Y_SPACING;

      valid_height = true;
    }
}

bool
ActNotesItem::same_day_p(const ActNotesItem &rhs) const
{
  update_date();
  rhs.update_date();

  return (day_of_month == rhs.day_of_month
	  && month == rhs.month && year == rhs.year);
}
