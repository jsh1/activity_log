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

#import "ActWeekViewController.h"

#import "ActAppDelegate.h"
#import "ActColor.h"
#import "ActWindowController.h"

#import "act-config.h"
#import "act-format.h"

#import "ActAppKitExtensions.h"
#import "ActFoundationExtensions.h"

#import <QuartzCore/CoreAnimation.h>

#define ROW_HEIGHT 90
#define STATS_WIDTH 100
#define COLUMN_SPACING 10
#define LEFT_BORDER 8
#define RIGHT_BORDER 20
#define STATS_X_INSET 0
#define STATS_Y_INSET 16
#define STATS_DATE_FONT_SIZE 12
#define STATS_MAIN_FONT_SIZE 24
#define STATS_SUB_FONT_SIZE 12
#define MIN_RADIUS 3

/* FIXME: should be calibrated dynamically? */
#define DIST_RADIUS_SCALE .8
#define DUR_RADIUS_SCALE 1.5
#define PTS_RADIUS_SCALE 20

#define SECONDS_PER_DAY 86400
#define SECONDS_PER_WEEK 604800

@class ActWeekView_StatsLayer, ActWeekView_GroupLayer;
@class ActWeekView_ActivityLayer, ActWeekView_ActivityGroupLayer;

@interface ActWeekView_ScaledLayer : CALayer
{
  CGFloat _interfaceScale;
  int _displayMode;
}

@property CGFloat interfaceScale;
@property(nonatomic) int displayMode;

@end

@interface ActWeekViewLayer : ActWeekView_ScaledLayer
{
  time_t _date;
  std::vector<act::database::item> _items;
  std::vector<act::activity *> _activities;

  ActWeekView_StatsLayer *_statsLayer;
  ActWeekView_GroupLayer *_groupLayer;
}

@property(nonatomic) time_t date;
@property(nonatomic) const std::vector<act::database::item> &items;
@property(nonatomic, readonly) const std::vector<act::activity *> &activities;

@property(nonatomic, readonly) ActWeekView_GroupLayer *groupLayer;

@end

@interface ActWeekView_StatsLayer : CATextLayer
{
  time_t _date;
  int _displayMode;
  double _distance;
  double _duration;
  double _points;
}

@property(nonatomic) time_t date;
@property(nonatomic) int displayMode;
@property(nonatomic) double distance;
@property(nonatomic) double duration;
@property(nonatomic) double points;

@end

@interface ActWeekView_GroupLayer : ActWeekView_ScaledLayer
{
  time_t _date;
  std::vector<act::activity *> _activities;
}

@property(nonatomic) time_t date;
@property(nonatomic) const std::vector<act::activity *> &activities;

@end

@interface ActWeekView_ActivityLayer : ActWeekView_ScaledLayer
{
  time_t _date;
  std::vector<act::activity *> _activities;
  BOOL _selected;
  BOOL _expanded, _expandable;

  CATextLayer *_textLayer;
  ActWeekView_ActivityGroupLayer *_groupLayer;
}

@property(nonatomic) time_t date;
@property(nonatomic) const std::vector<act::activity *> &activities;
@property(nonatomic, getter=isSelected) BOOL selected;
@property(nonatomic, getter=isExpanded) BOOL expanded;
@property(nonatomic, getter=isExpandable) BOOL expandable;

@property(nonatomic, readonly) ActWeekView_ActivityGroupLayer *groupLayer;

@end

@interface ActWeekView_ActivityGroupLayer : ActWeekView_ScaledLayer
{
  std::vector<act::activity *> _activities;
  BOOL _expanded;
}

@property(nonatomic) const std::vector<act::activity *> &activities;
@property(nonatomic, getter=isExpanded) BOOL expanded;

@end

static int
week_for_date(time_t date)
{
  // days since Jan 1, 1970 (a thursday); adjust, and into weeks:
  // (date / (24 * 60 * 60) + 4 - start_of_week) / 7, equiv. to:

  int start_of_week = act::shared_config().start_of_week();

  return (date - (start_of_week - 4) * SECONDS_PER_DAY) / SECONDS_PER_WEEK;
}

static time_t
date_for_week(int week)
{
  int start_of_week = act::shared_config().start_of_week();

  return week * SECONDS_PER_WEEK + (start_of_week - 4) * SECONDS_PER_DAY;
}

static CGFloat
activity_radius(double dist, double dur, double pts, int displayMode)
{
  double value, scale;
  if (displayMode == ActWeekView_Distance)
    value = dist, scale = DIST_RADIUS_SCALE;
  else if (displayMode == ActWeekView_Duration)
    value = dur, scale = DUR_RADIUS_SCALE;
  else /* if (displayMode == ActWeekView_Points) */
    value = pts, scale = PTS_RADIUS_SCALE;

  if (!(value > 0))
    {
      if (dist > 0)
	value = dist, scale = DIST_RADIUS_SCALE;
      else if (dur > 0)
	value = dur, scale = DUR_RADIUS_SCALE;
      else
	value = pts, scale = PTS_RADIUS_SCALE;
    }

  return sqrt(value * (1/M_PI)) * scale;
}

@implementation ActWeekViewController

@synthesize interfaceScale = _interfaceScale;
@synthesize displayMode = _displayMode;

+ (NSString *)viewNibName
{
  return @"ActWeekView";
}

- (id)initWithController:(ActWindowController *)controller
    options:(NSDictionary *)dict
{
  self = [super initWithController:controller options:dict];
  if (self == nil)
    return nil;

  _interfaceScale = .5;

  return self;
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

  /* This is so we update when the scroll view scrolls. */

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(listViewBoundsDidChange:)
   name:NSViewBoundsDidChangeNotification object:[_listView superview]];

  /* This is so we update when the list view changes size. */

  [_listView setPostsFrameChangedNotifications:YES];
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(listViewBoundsDidChange:)
   name:NSViewFrameDidChangeNotification object:_listView];

  [_scaleSlider setDoubleValue:_interfaceScale];
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

- (void)withAnimationsEnabled:(void (^)(void))thunk
{
  _animationsEnabled++;

  thunk();

  _animationsEnabled--;
}

- (int)weekForActivityStorage:(const act::activity_storage_ref)storage
{
  if (storage == nullptr)
    return NSNotFound;

  const auto &activities = [_controller activityList];

  for (size_t i = 0; i < activities.size(); i++)
    {
      if (activities[i].storage() == storage)
	return week_for_date(activities[i].date());
    }

  return -1;
}

- (void)activityListDidChange:(NSNotification *)note
{
  const auto &activities = [_controller activityList];

  int first_week = 0;
  int last_week = 0;

  if (activities.size() != 0)
    {
      first_week = week_for_date(activities.back().date());
      last_week = week_for_date(activities.front().date());
    }

  [_listView setWeekRange:NSMakeRange(first_week, last_week + 1 - first_week)];
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  int week = [self weekForActivityStorage:
	      [_controller selectedActivityStorage]];

  if (week >= 0)
    {
      NSRect r = [_listView rectForWeek:week];
      [_listView scrollRectToVisible:r];
    }

  [_listView setNeedsDisplay:YES];
}

- (void)activityDidChangeField:(NSNotification *)note
{
  void *ptr = [[[note userInfo] objectForKey:@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);

  int week = [self weekForActivityStorage:a];
  if (week <= 0)
    return;

  [_listView setNeedsDisplayInRect:[_listView visibleRectForWeek:week]];
}

- (void)listViewBoundsDidChange:(NSNotification *)note
{
  [_listView setNeedsDisplay:YES];
}

- (IBAction)controlAction:(id)sender
{
  if (sender == _scaleSlider)
    {
      _interfaceScale = [sender doubleValue];

      BOOL disableAnimations = YES;
      switch ([[[[self view] window] currentEvent] type])
	{
	case NSLeftMouseDown:
	case NSRightMouseDown:
	case NSOtherMouseDown:
	  disableAnimations = NO;
	}

      if (disableAnimations)
	_animationsDisabled++;

      [_listView setNeedsDisplay:YES];

      if (disableAnimations)
	dispatch_async(dispatch_get_main_queue(), ^{_animationsDisabled--;});
    }
  else if (sender == _displayModeControl)
    {
      _displayMode = [sender selectedSegment];

      [_listView setNeedsDisplay:YES];
    }
}

- (NSDictionary *)savedViewState
{
  return @{
    @"interfaceScale": @(_interfaceScale),
    @"displayMode": @(_displayMode)
  };
}

- (void)applySavedViewState:(NSDictionary *)state
{
  if (NSNumber *obj = [state objectForKey:@"interfaceScale"])
    _interfaceScale = [obj doubleValue];

  if (NSNumber *obj = [state objectForKey:@"displayMode"])
    _displayMode = [obj intValue];

  if (_scaleSlider != nil)
    [_scaleSlider setDoubleValue:_interfaceScale];
  if (_displayModeControl != nil)
    [_displayModeControl setSelectedSegment:_displayMode];
}

// CALayerDelegate methods

- (id)actionForLayer:(CALayer *)layer forKey:(NSString *)key
{
  return !_animationsEnabled || _animationsDisabled ? [NSNull null] : nil;
}

@end

@implementation ActWeekListView

- (void)dealloc
{
  [_expandedLayer release];
  [_selectedLayer release];
  [super dealloc];
}

- (NSRange)weekRange
{
  return _weekRange;
}

- (void)setWeekRange:(NSRange)x
{
  if (!NSEqualRanges(_weekRange, x))
    {
      _weekRange = x;
      [self setNeedsDisplay:YES];
    }
}

- (NSRect)rectForWeek:(int)week
{
  if (week < _weekRange.location
      || week >= _weekRange.location + _weekRange.length)
    return NSZeroRect;

  NSRect bounds = [self bounds];

  return NSMakeRect(bounds.origin.x, bounds.origin.y + bounds.size.height
		    - ((week + 1) - _weekRange.location) * ROW_HEIGHT,
		    bounds.size.width, ROW_HEIGHT);
}

- (NSRect)visibleRectForWeek:(int)week
{
  NSRect vis_rect = [self visibleRect];

  if (NSIsEmptyRect(vis_rect))
    return vis_rect;

  return NSIntersectionRect([self rectForWeek:week], vis_rect);
}

- (ActWeekView_GroupLayer *)groupLayerForWeek:(int)week
{
  if (!(week >= 0))
    return nil;

  time_t date = date_for_week(week);

  for (ActWeekViewLayer *layer in [[self layer] sublayers])
    {
      if ([layer date] == date)
	return [layer groupLayer];
    }

  return nil;
}

- (BOOL)wantsUpdateLayer
{
  return YES;
}

- (void)updateFrameSize
{
  NSRect frame = [self frame];
  CGFloat h = ROW_HEIGHT * _weekRange.length;

  if (frame.size.height != h)
    {
      [self setFrameSize:NSMakeSize(frame.size.width, h)];
      [self flashScrollersIfNeeded];
    }

  NSRect bounds = [self bounds];

  if (_trackingArea == nil
      || !NSEqualRects(bounds, [_trackingArea rect]))
    {
      [self removeTrackingArea:_trackingArea];
      _trackingArea = [[NSTrackingArea alloc] initWithRect:bounds
		       options:(NSTrackingMouseEnteredAndExited
				| NSTrackingMouseMoved
				| NSTrackingActiveInKeyWindow)
		       owner:self userInfo:nil];
      [self addTrackingArea:_trackingArea];
      [_trackingArea release];
    }
}

- (void)updateLayersForRect:(NSRect)rect
{
  NSRect bounds = [self bounds];

  int y0 = floor((rect.origin.y - bounds.origin.y) / ROW_HEIGHT);
  int y1 = ceil((rect.origin.y + rect.size.height - bounds.origin.y) / ROW_HEIGHT);
  if (y0 < 0) y0 = 0;
  if (y1 < 0) y1 = 0;

  CGFloat backing_scale = [[self window] backingScaleFactor];
  CGFloat interface_scale = [_controller interfaceScale];

  CALayer *layer = [self layer];
  NSMutableArray *old_sublayers = [[layer sublayers] mutableCopy];
  NSMutableArray *new_sublayers = [[NSMutableArray alloc] init];

  const auto &activities = [[_controller controller] activityList];

  int week_idx = _weekRange.location + (_weekRange.length - (y0 + 1));

  time_t week_date = date_for_week(week_idx);

  /* Find first item whose date is at or before the end of the first
     week we're going to look at. */

  auto item = std::lower_bound(activities.cbegin(), activities.cend(),
			       week_date + SECONDS_PER_WEEK,
			       [] (const act::database::item &a, time_t d) {
				 return d < a.date();
			       });

  for (int y = y0; y < y1; y++)
    {
      if (y >= _weekRange.length)
	break;

      ActWeekViewLayer *sublayer = nil;

      NSInteger old_idx = 0;
      for (ActWeekViewLayer *tem in old_sublayers)
	{
	  if ([tem date] == week_date)
	    {
	      [old_sublayers removeObjectAtIndex:old_idx];
	      sublayer = tem;
	      break;
	    }
	  old_idx++;
	}

      if (sublayer == nil)
	{
	  sublayer = [ActWeekViewLayer layer];
	  [sublayer setDate:week_date];
	  [sublayer setDelegate:_controller];
	}
      
      [sublayer setFrame:CGRectMake(bounds.origin.x + LEFT_BORDER,
		bounds.origin.y + ROW_HEIGHT * y, bounds.size.width
		- (LEFT_BORDER + RIGHT_BORDER * interface_scale), ROW_HEIGHT)];
      [sublayer setContentsScale:backing_scale];

      [new_sublayers addObject:sublayer];

      std::vector<act::database::item> week_vec;
      while (item != activities.cend() && !(item->date() < week_date))
	week_vec.push_back(*item++);

      [sublayer setItems:week_vec];
      [sublayer setInterfaceScale:interface_scale];
      [sublayer setNeedsLayout];

      week_date = week_date - SECONDS_PER_WEEK;
    }

  [layer setSublayers:new_sublayers];

  [new_sublayers release];
  [old_sublayers release];

  [layer setBackgroundColor:[[ActColor midControlBackgroundColor] CGColor]];

  [self setPreparedContentRect:rect];
}

static ActWeekView_ActivityLayer *
activityLayerForStorage(NSArray *sublayers, act::activity_storage_ref storage)
{
  for (ActWeekView_ActivityLayer *layer in sublayers)
    {
      const std::vector<act::activity *> &vec = [layer activities];
      if (std::any_of(vec.begin(), vec.end(),
		      [=] (act::activity *a) {
			return a->storage() == storage;}))
	return layer;
    }

  return nil;
}

- (void)updateSelectionState
{
  act::activity_storage_ref storage
    = [[_controller controller] selectedActivityStorage];

  ActWeekView_ActivityLayer *selected_layer = nil;

  if (storage != nullptr)
    {
      int week = [_controller weekForActivityStorage:storage];
      ActWeekView_GroupLayer *glayer = [self groupLayerForWeek:week];
      selected_layer = activityLayerForStorage([glayer sublayers], storage);
      ActWeekView_ActivityGroupLayer *aglayer = [selected_layer groupLayer];
      if (aglayer != nil)
	selected_layer = activityLayerForStorage([aglayer sublayers], storage);
    }

  if (_selectedLayer != selected_layer)
    {
      [_selectedLayer setSelected:NO];

      [_selectedLayer release];
      _selectedLayer = [selected_layer retain];

      [_selectedLayer setSelected:YES];
    }
}

- (void)updateLayer
{
  [self updateFrameSize];
  [self updateLayersForRect:[self visibleRect]];
  [self updateSelectionState];
}

- (BOOL)isFlipped
{
  return YES;
}

- (BOOL)isOpaque
{
  return YES;
}

- (void)mouseDown:(NSEvent *)e
{
  NSPoint p = [[self superview] convertPoint:[e locationInWindow]
	       fromView:nil];

  CALayer *self_layer = [self layer];
  CALayer *layer = [self_layer hitTest:NSPointToCGPoint(p)];

  while (layer != nil && layer != self_layer)
    {
      if ([layer isKindOfClass:[ActWeekView_ActivityLayer class]])
	{
	  ActWeekView_ActivityLayer *a_layer = (id)layer;
	  const std::vector<act::activity *> &vec = [a_layer activities];

	  if (vec.size() == 1)
	    {
	      [[_controller controller]
	       setSelectedActivityStorage:vec[0]->storage()];
	      break;
	    }
	}

      layer = [layer superlayer];
    }
}

- (void)mouseMoved:(NSEvent *)e
{
  NSPoint p = [[self superview] convertPoint:[e locationInWindow]
	       fromView:nil];

  CALayer *self_layer = [self layer];
  CALayer *layer = [self_layer hitTest:NSPointToCGPoint(p)];
  ActWeekView_ActivityLayer *expanded_layer = nil;

  while (layer != nil && layer != self_layer)
    {
      if ([layer isKindOfClass:[ActWeekView_ActivityLayer class]]
	  && [(ActWeekView_ActivityLayer *)layer isExpandable])
	{
	  expanded_layer = (ActWeekView_ActivityLayer *)layer;
	  break;
	}

      layer = [layer superlayer];
    }

  if (expanded_layer != _expandedLayer)
    {
      [_expandedLayer setExpanded:NO];
      [_expandedLayer release];
      _expandedLayer = [expanded_layer retain];
      [_expandedLayer setExpanded:YES];
    }
}

- (void)mouseExited:(NSEvent *)e
{
  if (_expandedLayer != nil)
    {
      [_expandedLayer setExpanded:NO];
      [_expandedLayer release];
      _expandedLayer = nil;
    }
}

@end

@implementation ActWeekHeaderView

- (void)drawRect:(NSRect)r
{
  static NSGradient *grad;
  static NSColor *separator_color;
  static dispatch_once_t once;

  dispatch_once(&once, ^
    {
      grad = [[NSGradient alloc] initWithStartingColor:
	      [ActColor darkControlBackgroundColor] endingColor:
	      [ActColor controlBackgroundColor]];

      separator_color = [[NSColor colorWithDeviceWhite:.80 alpha:1] retain];
    });

  NSRect bounds = [self bounds];

  [grad drawInRect:bounds angle:90];

  // draw separator

  NSRect subR;
  subR.origin.x = bounds.origin.x;
  subR.origin.y = bounds.origin.y + 1;
  subR.size.width = bounds.size.width;
  subR.size.height = 1;

  [separator_color setFill];
  [NSBezierPath fillRect:subR];
  subR.origin.y -= 1;
  [[ActColor whiteColor] setFill];
  [NSBezierPath fillRect:subR];
}

- (BOOL)isOpaque
{
  return YES;
}

@end

@implementation ActWeekView_ScaledLayer

- (CGFloat)interfaceScale
{
  return _interfaceScale;
}

- (void)setInterfaceScale:(CGFloat)x
{
  if (_interfaceScale != x)
    {
      _interfaceScale = x;
      [self setNeedsLayout];
    }
}

- (int)displayMode
{
  return _displayMode;
}

- (void)setDisplayMode:(int)x
{
  if (_displayMode != x)
    {
      _displayMode = x;
      [self setNeedsLayout];
    }
}

@end

@implementation ActWeekViewLayer

@synthesize activities = _activities;
@synthesize groupLayer = _groupLayer;

- (time_t)date
{
  return _date;
}

- (void)setDate:(time_t)x
{
  if (_date != x)
    {
      _date = x;
      [self setNeedsLayout];
    }
}

- (const std::vector<act::database::item> &)items
{
  return _items;
}

- (void)setItems:(const std::vector<act::database::item> &)vec
{
  if (_items != vec)
    {
      _items = vec;
      [self setNeedsLayout];
    }
}

- (void)dealloc
{
  for (size_t i = 0; i < _activities.size(); i++)
    delete _activities[i];

  [super dealloc];
}

- (void)updateActivities
{
  if (_activities.size() != _items.size())
    {
      for (size_t i = _items.size(); i < _activities.size(); i++)
	delete _activities[i];

      _activities.resize(_items.size());
    }

  for (size_t i = 0; i < _items.size(); i++)
    {
      if (_activities[i] != nullptr
	  && _activities[i]->storage() != _items[i].storage())
	{
	  delete _activities[i];
	  _activities[i] = nullptr;
	}

      if (_activities[i] == nullptr)
	_activities[i] = new act::activity(_items[i].storage());
    }
}

- (void)layoutSublayers
{
  if (_statsLayer == nil)
    {
      _statsLayer = [ActWeekView_StatsLayer layer];
      [_statsLayer setDelegate:[self delegate]];
      [self addSublayer:_statsLayer];
    }

  if (_groupLayer == nil)
    {
      _groupLayer = [ActWeekView_GroupLayer layer];
      [_groupLayer setDelegate:[self delegate]];
      [self addSublayer:_groupLayer];
    }

  [self updateActivities];

  double distance = 0;
  double duration = 0;
  double points = 0;

  for (const auto &it : _activities)
    {
      distance += it->distance();
      duration += it->duration();
      points += it->points();
    }

  CGRect bounds = [self bounds];
  int displayMode = [(ActWeekViewController *)[self delegate] displayMode];

  [_statsLayer setDate:_date];
  [_statsLayer setDisplayMode:displayMode];
  [_statsLayer setDistance:distance];
  [_statsLayer setDuration:duration];
  [_statsLayer setPoints:points];
  CGRect sr = CGRectMake(bounds.origin.x, bounds.origin.y,
			 STATS_WIDTH, bounds.size.height);
  sr = CGRectInset(sr, STATS_X_INSET, STATS_Y_INSET);
  [_statsLayer setFrame:sr];
  [_statsLayer setContentsScale:[self contentsScale]];

  [_groupLayer setInterfaceScale:[self interfaceScale]];
  [_groupLayer setDate:_date];
  [_groupLayer setActivities:_activities];
  [_groupLayer setDisplayMode:displayMode];
  CGFloat xoff = STATS_WIDTH + COLUMN_SPACING;
  [_groupLayer setFrame:CGRectMake(bounds.origin.x + xoff,
	bounds.origin.y, bounds.size.width - xoff, bounds.size.height)];
  [_groupLayer setContentsScale:[self contentsScale]];
}

@end

@implementation ActWeekView_StatsLayer

+ (id)defaultValueForKey:(NSString *)key
{
  if ([key isEqualToString:@"wrapped"])
    return @YES;

  return [super defaultValueForKey:key];
}

- (time_t)date
{
  return _date;
}

- (void)setDate:(time_t)x
{
  if (_date != x)
    {
      _date = x;
      [self setNeedsLayout];
    }
}

- (int)displayMode
{
  return _displayMode;
}

- (void)setDisplayMode:(int)x
{
  if (_displayMode != x)
    {
      _displayMode = x;
      [self setNeedsLayout];
    }
}

- (double)distance
{
  return _distance;
}

- (void)setDistance:(double)x
{
  if (_distance != x)
    {
      _distance = x;
      [self setNeedsLayout];
    }
}

- (double)duration
{
  return _duration;
}

- (void)setDuration:(double)x
{
  if (_duration != x)
    {
      _duration = x;
      [self setNeedsLayout];
    }
}

- (double)points
{
  return _points;
}

- (void)setPoints:(double)x
{
  if (_points != x)
    {
      _points = x;
      [self setNeedsLayout];
    }
}

- (void)layoutSublayers
{
  static NSDateFormatter *date_formatter;
  static NSDictionary *date_attrs, *main_attrs, *sub_attrs;
  static NSString *en_dash;
  static dispatch_once_t once;

  dispatch_once(&once, ^
    {
      NSLocale *locale = [(ActAppDelegate *)[NSApp delegate] currentLocale];

      date_formatter = [[NSDateFormatter alloc] init];
      [date_formatter setLocale:locale];
      [date_formatter setDateFormat:
       [NSDateFormatter dateFormatFromTemplate:@"MMdd" options:0
	locale:locale]];

      NSColor *greyColor = [ActColor controlTextColor];
      NSColor *redColor = [ActColor controlDetailTextColor];

      date_attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
		    [NSFont fontWithName:@"Helvetica Neue"
		     size:STATS_DATE_FONT_SIZE], NSFontAttributeName,
		    greyColor, NSForegroundColorAttributeName,
		    nil];
      main_attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
		    [NSFont fontWithName:@"Helvetica Neue"
		     size:STATS_MAIN_FONT_SIZE], NSFontAttributeName,
		    redColor, NSForegroundColorAttributeName,
		    nil];
      sub_attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
		    [NSFont fontWithName:@"Helvetica Neue"
		     size:STATS_SUB_FONT_SIZE], NSFontAttributeName,
		    greyColor, NSForegroundColorAttributeName,
		    nil];

      unichar c = 0x2013;
      en_dash = [[NSString alloc] initWithCharacters:&c length:1];
    });

  time_t start_date = _date;
  time_t end_date = _date + SECONDS_PER_WEEK;

  NSString *date_str = [NSString stringWithFormat:@"%@ %@ %@\n",
			[date_formatter stringFromDate:
			 [NSDate dateWithTimeIntervalSince1970:start_date]],
			en_dash,
			[date_formatter stringFromDate:
			 [NSDate dateWithTimeIntervalSince1970:end_date]]];

  size_t date_len = [date_str length];

  std::string dist_str;
  act::format_distance(dist_str, _distance, act::unit_type::unknown);

  int hours = floor(_duration / 3600);
  int mins = round((_duration - hours*3600) / 60);
  int pts = round(_points);

  char dur_buf[32];
  snprintf(dur_buf, sizeof(dur_buf), "%dh %02dm", hours, mins);

  char pts_buf[32];
  snprintf(pts_buf, sizeof(pts_buf), "%d pts", pts);

  std::string rest;

  if (_displayMode == ActWeekView_Distance)
    rest.append(dist_str);
  else if (_displayMode == ActWeekView_Duration)
    rest.append(dur_buf);
  else
    rest.append(pts_buf);

  rest.push_back('\n');

  size_t main_len = rest.size();

  if (_displayMode == ActWeekView_Distance)
    rest.append(dur_buf);
  else
    rest.append(dist_str);

  rest.append(", ");

  if (_displayMode == ActWeekView_Points)
    rest.append(dur_buf);
  else
    rest.append(pts_buf);
  
  size_t sub_len = rest.size() - main_len;

  NSString *str = [date_str stringByAppendingString:
		   [NSString stringWithUTF8String:rest.c_str()]];

  NSMutableAttributedString *astr = [[NSMutableAttributedString alloc]
				     initWithString:str];

  [astr setAttributes:date_attrs range:NSMakeRange(0, date_len)];
  [astr setAttributes:main_attrs range:NSMakeRange(date_len, main_len)];
  [astr setAttributes:sub_attrs range:NSMakeRange(date_len + main_len, sub_len)];

  [self setString:astr];
}

- (void)drawInContext:(CGContextRef)ctx
{
  CGContextSetFillColorWithColor(ctx, [[ActColor midControlBackgroundColor] CGColor]);
  CGContextFillRect(ctx, [self bounds]);
  CGContextSetShouldSmoothFonts(ctx, true);
  [super drawInContext:ctx];
}

@end

@implementation ActWeekView_GroupLayer

- (time_t)date
{
  return _date;
}

- (void)setDate:(time_t)x
{
  if (_date != x)
    {
      _date = x;
      [self setNeedsLayout];
    }
}

- (const std::vector<act::activity *> &)activities
{
  return _activities;
}

- (void)setActivities:(const std::vector<act::activity *> &)vec
{
  if (_activities != vec)
    {
      _activities = vec;
      [self setNeedsLayout];
    }
}

- (void)layoutSublayers
{
  NSMutableArray *old_sublayers = [[self sublayers] mutableCopy];
  NSMutableArray *new_sublayers = [[NSMutableArray alloc] init];

  CGRect bounds = [self bounds];
  CGFloat item_width = floor(bounds.size.width / 7);

  ssize_t item_i = _activities.size() - 1;
  time_t day_date = _date;

  for (int i = 0; i < 7; i++)
    {
      ActWeekView_ActivityLayer *sublayer = nil;

      NSInteger old_idx = 0;
      for (ActWeekView_ActivityLayer *tem in old_sublayers)
	{
	  if ([tem date] == day_date)
	    {
	      [old_sublayers removeObjectAtIndex:old_idx];
	      sublayer = tem;
	      break;
	    }
	  old_idx++;
	}

      if (sublayer == nil)
	{
	  sublayer = [ActWeekView_ActivityLayer layer];
	  [sublayer setDate:day_date];
	  [sublayer setExpandable:YES];
	  [sublayer setDelegate:[self delegate]];
	}

      CGFloat px = bounds.origin.x + floor(i * item_width + item_width * .5);
      CGFloat py = bounds.origin.y + floor(ROW_HEIGHT * .5);

      [(ActWeekViewController *)[self delegate] withAnimationsEnabled:^
        {
	  [sublayer setPosition:CGPointMake(px, py)];
	}];

      [sublayer setContentsScale:[self contentsScale]];

      [new_sublayers addObject:sublayer];

      time_t next_day_date = day_date + SECONDS_PER_DAY;

      std::vector<act::activity *> day_vec;
      while (item_i >= 0 && (_activities[item_i]->date() < next_day_date))
	{
	  day_vec.push_back(_activities[item_i]);
	  item_i--;
	}

      [sublayer setActivities:day_vec];
      [sublayer setDisplayMode:[self displayMode]];
      [sublayer setInterfaceScale:[self interfaceScale]];

      day_date = next_day_date;
    }

  [self setSublayers:new_sublayers];

  [new_sublayers release];
  [old_sublayers release];
}

@end

@implementation ActWeekView_ActivityLayer

@synthesize date = _date;
@synthesize expandable = _expandable;
@synthesize groupLayer = _groupLayer;

+ (id)defaultValueForKey:(NSString *)key
{
  if ([key isEqualToString:@"borderWidth"])
    return @1;
  else if ([key isEqualToString:@"borderColor"])
    return (id)[[NSColor colorWithDeviceWhite:0 alpha:.25] CGColor];
  else if ([key isEqualToString:@"shadowOffset"])
    return [NSValue valueWithSize:NSMakeSize(0, 2)];
  else if ([key isEqualToString:@"shadowRadius"])
    return @1.5;
  else if ([key isEqualToString:@"shadowPathIsBounds"])
    return @YES;

  return [super defaultValueForKey:key];
}

- (const std::vector<act::activity *> &)activities
{
  return _activities;
}

- (void)setActivities:(const std::vector<act::activity *> &)vec
{
  if (_activities != vec)
    {
      _activities = vec;
      [self setNeedsLayout];
    }
}

- (BOOL)isExpanded
{
  return _expanded;
}

- (void)setExpanded:(BOOL)flag
{
  if (_expanded != flag)
    {
      _expanded = flag;
      [self setNeedsLayout];
    }
}

- (BOOL)isSelected
{
  return _selected;
}

- (void)setSelected:(BOOL)flag
{
  if (_selected != flag)
    {
      _selected = flag;
      [self setNeedsLayout];
    }
}

- (void)layoutSublayers
{
  double dist = 0, dur = 0, pts = 0;
  for (const auto &it : _activities)
    {
      dist += it->distance();
      dur += it->duration();
      pts += it->points();
    }

  CGFloat scale = [self interfaceScale];

  CGFloat radius = activity_radius(dist, dur, pts, [self displayMode]);
  radius = round(radius * scale);
  if (radius < MIN_RADIUS)
    radius = MIN_RADIUS;

  if (_date != 0)
    {
      /* FIXME: create text layer. */
    }
  else if (_textLayer != nil)
    {
      [_textLayer removeFromSuperlayer];
      _textLayer = nil;
    }

  NSColor *color = nil;
  if (_activities.size() == 1)
    color = [ActColor activityColor:*_activities[0]];
  else
    color = [NSColor colorWithDeviceWhite:.5 alpha:1];

  NSColor *background_color = nil;
  if (_activities.size() == 1)
    background_color = [color blendedColorWithFraction:.6 ofColor:[NSColor whiteColor]];
  else
    background_color = [NSColor colorWithDeviceWhite:.85 alpha:1];

  NSColor *border_color = nil;
  if (!_selected)
    border_color = color;
  else
    border_color = [ActColor alternateSelectedControlColor];
  
  BOOL shadowed = _expanded && _activities.size() == 1;

  [(ActWeekViewController *)[self delegate] withAnimationsEnabled:^
    {
      [self setBounds:CGRectMake(0, 0, radius*2, radius*2)];
      [self setCornerRadius:radius];
      [self setBackgroundColor:[background_color CGColor]];
      [self setBorderColor:[border_color CGColor]];
      [self setBorderWidth:_selected ? 4 : _activities.size() == 1 ? 1 : 0];
      [self setShadowOpacity:shadowed ? .5 : 0];
    }];

  [self setZPosition:_expanded ? 1 : 0];

  if (_activities.size() > 1)
    {
      if (_groupLayer == nil)
	{
	  _groupLayer = [ActWeekView_ActivityGroupLayer layer];
	  [_groupLayer setDelegate:[self delegate]];
	  [self addSublayer:_groupLayer];
	}

      [_groupLayer setInterfaceScale:scale];
      [_groupLayer setActivities:_activities];
      [_groupLayer setDisplayMode:[self displayMode]];
      [_groupLayer setExpanded:_expanded];
      [_groupLayer setFrame:[self bounds]];
    }
  else if (_groupLayer != nil)
    {
      [_groupLayer removeFromSuperlayer];
      _groupLayer = nil;
    }
}

@end

@implementation ActWeekView_ActivityGroupLayer

- (const std::vector<act::activity *> &)activities
{
  return _activities;
}

- (void)setActivities:(const std::vector<act::activity *> &)vec
{
  if (_activities != vec)
    {
      _activities = vec;
      [self setNeedsLayout];
    }
}

- (BOOL)isExpanded
{
  return _expanded;
}

- (void)setExpanded:(BOOL)flag
{
  if (_expanded != flag)
    {
      _expanded = flag;
      [self setNeedsLayout];
    }
}

- (void)layoutSublayers
{
  NSArray *sublayers = [NSArray arrayWithArray:[self sublayers]];
  size_t count = [sublayers count];

  while (count > _activities.size())
    {
      [[sublayers objectAtIndex:count-1] removeFromSuperlayer];
      count--;
    }

  CGRect bounds = [self bounds];

  CGFloat cx = bounds.origin.x + floor(bounds.size.width * .5);
  CGFloat cy = bounds.origin.y + floor(bounds.size.height * .5);

  double ang_step = (2 * M_PI) / _activities.size();

  CGFloat scale = [self interfaceScale];

  for (size_t i = 0; i < _activities.size(); i++)
    {
      ActWeekView_ActivityLayer *sublayer = nil;

      if (i < count)
	sublayer = [sublayers objectAtIndex:i];
      else
	{
	  sublayer = [ActWeekView_ActivityLayer layer];
	  [sublayer setDelegate:[self delegate]];
	  [self addSublayer:sublayer];
	}

      double dist = _activities[i]->distance();
      double dur = _activities[i]->duration();
      double pts = _activities[i]->points();

      CGFloat radius = activity_radius(dist, dur, pts, [self displayMode]);
      radius = round(radius * scale);
      CGFloat ang = i * ang_step + M_PI;
      CGFloat hyp = bounds.size.width * .5 - radius * (_expanded ? .4 : 1);
      CGFloat px = cx + sin(ang) * hyp;
      CGFloat py = cy + cos(ang) * hyp;

      [(ActWeekViewController *)[self delegate] withAnimationsEnabled:^
        {
	  [sublayer setPosition:CGPointMake(px, py)];
	}];

      [sublayer setInterfaceScale:scale];
      [sublayer setDisplayMode:[self displayMode]];
      [sublayer setExpanded:_expanded];
      [sublayer setContentsScale:[self contentsScale]];

      std::vector<act::activity *> day_vec;
      day_vec.push_back(_activities[i]);

      [sublayer setActivities:day_vec];
    }
}

@end
