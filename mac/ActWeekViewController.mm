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
#import "ActFont.h"
#import "ActWindowController.h"

#import "act-config.h"
#import "act-format.h"
#import "act-util.h"

#import "AppKitExtensions.h"
#import "CoreAnimationExtensions.h"
#import "FoundationExtensions.h"

#define ROW_HEIGHT 80
#define STATS_WIDTH 100
#define COLUMN_SPACING 2
#define LEFT_BORDER 10
#define RIGHT_BORDER 15
#define STATS_X_INSET 0
#define STATS_Y_INSET 11
#define STATS_DATE_FONT_SIZE 12
#define STATS_MAIN_FONT_SIZE 24
#define STATS_SUB_FONT_SIZE 12
#define HEADER_MONTH_FONT_SIZE 16
#define HEADER_MONTH_Y 0
#define HEADER_MONTH_HEIGHT 25
#define HEADER_DAY_FONT_SIZE 12
#define HEADER_DAY_Y 3
#define HEADER_DAY_HEIGHT 20
#define MIN_RADIUS 3

/* FIXME: should be calibrated dynamically? */
#define DIST_RADIUS_SCALE .8
#define DUR_RADIUS_SCALE 1.5
#define PTS_RADIUS_SCALE 20

#define SECONDS_PER_DAY 86400
#define SECONDS_PER_WEEK 604800

@class ActWeekView_StatsLayer, ActWeekView_GroupLayer;
@class ActWeekView_ActivityLayer, ActWeekView_ActivityGroupLayer;

@interface ActWeekViewController ()
- (void)activityListDidChange:(NSNotification *)note;
- (void)selectedActivityDidChange:(NSNotification *)note;
@end

@interface ActWeekListView ()
- (void)updatePopover;
@end

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
  std::vector<act::activity_ref> _activities;

  ActWeekView_StatsLayer *_statsLayer;
  ActWeekView_GroupLayer *_groupLayer;
}

@property(nonatomic) time_t date;
@property(nonatomic) const std::vector<act::database::item> &items;
@property(nonatomic, readonly) const std::vector<act::activity_ref> &activities;

@property(nonatomic, strong, readonly) ActWeekView_GroupLayer *groupLayer;

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
  std::vector<act::activity_ref> _activities;
}

@property(nonatomic) time_t date;
@property(nonatomic) const std::vector<act::activity_ref> &activities;

@end

@interface ActWeekView_ActivityLayer : ActWeekView_ScaledLayer
{
  time_t _date;
  std::vector<act::activity_ref> _activities;
  BOOL _highlit;
  BOOL _expanded, _expandable;

  CATextLayer *_textLayer;
  ActWeekView_ActivityGroupLayer *_groupLayer;
}

@property(nonatomic) time_t date;
@property(nonatomic) const std::vector<act::activity_ref> &activities;
@property(nonatomic, getter=isHighlit) BOOL highlit;
@property(nonatomic, getter=isExpanded) BOOL expanded;
@property(nonatomic, getter=isExpandable) BOOL expandable;

@property(nonatomic, strong, readonly) ActWeekView_ActivityGroupLayer *groupLayer;

@end

@interface ActWeekView_ActivityGroupLayer : ActWeekView_ScaledLayer
{
  std::vector<act::activity_ref> _activities;
  BOOL _expanded;
}

@property(nonatomic) const std::vector<act::activity_ref> &activities;
@property(nonatomic, getter=isExpanded) BOOL expanded;

@end

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

@synthesize scrollView = _scrollView;
@synthesize listView = _listView;
@synthesize headerView = _headerView;
@synthesize displayModeControl = _displayModeControl;
@synthesize scaleSlider = _scaleSlider;
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
   name:ActActivityListDidChange object:self.controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:self.controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeField:)
   name:ActActivityDidChangeField object:self.controller];

  /* This is so we update when the scroll view scrolls. */

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(listViewBoundsDidChange:)
   name:NSViewBoundsDidChangeNotification object:_listView.superview];

  /* This is so we update when the list view changes size. */

  _listView.postsFrameChangedNotifications = YES;
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(listViewBoundsDidChange:)
   name:NSViewFrameDidChangeNotification object:_listView];

  _scrollView.backgroundColor = [ActColor midControlBackgroundColor];

  _scaleSlider.doubleValue = _interfaceScale;
}

- (void)viewWillAppear
{
  [self activityListDidChange:nil];
  [self selectedActivityDidChange:nil];
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

- (int)weekForActivityStorage:(const act::activity_storage_ref)storage
{
  if (storage == nullptr)
    return -1;

  const auto &activities = self.controller.activityList;

  for (size_t i = 0; i < activities.size(); i++)
    {
      if (activities[i].storage() == storage)
	return act::week_index(activities[i].date());
    }

  return -1;
}

- (void)activityListDidChange:(NSNotification *)note
{
  const auto &activities = self.controller.activityList;

  int first_week = 0;
  int last_week = 0;

  if (activities.size() != 0)
    {
      first_week = act::week_index(activities.back().date());
      last_week = act::week_index(activities.front().date());
    }

  _listView.weekRange = NSMakeRange(first_week, last_week + 1 - first_week);
  _listView.needsDisplay = YES;
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  int week = [self weekForActivityStorage:self.controller.selectedActivityStorage];

  if (week >= 0)
    {
      NSRect r = [_listView rectForWeek:week];
      [_listView scrollRectToVisible:r animated:YES];
    }

  _listView.needsDisplay = YES;
}

- (void)activityDidChangeField:(NSNotification *)note
{
  void *ptr = [note.userInfo[@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);

  [_listView invalidateActivityStorage:a];
}

- (void)listViewBoundsDidChange:(NSNotification *)note
{
  _listView.needsDisplay = YES;
}

- (IBAction)controlAction:(id)sender
{
  if (sender == _scaleSlider)
    {
      _interfaceScale = [sender doubleValue];

      BOOL disableAnimations = YES;
      switch (self.view.window.currentEvent.type)
	{
	case NSLeftMouseDown:
	case NSRightMouseDown:
	case NSOtherMouseDown:
	  disableAnimations = NO;
	  break;
	default:
	  break;
	}

      if (disableAnimations)
	[CATransaction setDisableActions:YES];

      _listView.needsDisplay = YES;
      _headerView.needsDisplay = YES;
    }
  else if (sender == _displayModeControl)
    {
      _displayMode = [sender selectedSegment];

      _listView.needsDisplay = YES;
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
  if (NSNumber *obj = state[@"interfaceScale"])
    _interfaceScale = obj.doubleValue;

  if (NSNumber *obj = state[@"displayMode"])
    _displayMode = obj.intValue;

  if (_scaleSlider != nil)
    _scaleSlider.doubleValue = _interfaceScale;
  if (_displayModeControl != nil)
    _displayModeControl.selectedSegment = _displayMode;
}

// CALayerDelegate methods

- (id)actionForLayer:(CALayer *)layer forKey:(NSString *)key
{
  return [CATransaction actionForLayer:layer forKey:key];
}

@end

@implementation ActWeekListView
{
  NSTrackingArea *_trackingArea;

  ActWeekView_ActivityLayer *_expandedLayer;
  ActWeekView_ActivityLayer *_highlitLayer;
  ActWeekView_ActivityLayer *_selectedLayer;
}

@synthesize controller = _controller;
@synthesize weekRange = _weekRange;

- (void)setWeekRange:(NSRange)x
{
  if (!NSEqualRanges(_weekRange, x))
    {
      _weekRange = x;
      self.needsDisplay = YES;
    }
}

- (NSRect)rectForWeek:(int)week
{
  if (week < _weekRange.location
      || week >= _weekRange.location + _weekRange.length)
    return NSZeroRect;

  NSRect bounds = self.bounds;

  return NSMakeRect(bounds.origin.x, bounds.origin.y + bounds.size.height
		    - ((week + 1) - _weekRange.location) * ROW_HEIGHT,
		    bounds.size.width, ROW_HEIGHT);
}

- (NSRect)visibleRectForWeek:(int)week
{
  NSRect vis_rect = self.visibleRect;

  if (NSIsEmptyRect(vis_rect))
    return vis_rect;

  return NSIntersectionRect([self rectForWeek:week], vis_rect);
}

- (ActWeekView_GroupLayer *)groupLayerForWeek:(int)week
{
  if (!(week >= 0))
    return nil;

  time_t date = act::week_date(week);

  for (ActWeekViewLayer *layer in self.layer.sublayers)
    {
      if (layer.date == date)
	return layer.groupLayer;
    }

  return nil;
}

static ActWeekView_ActivityLayer *
activityLayerForStorage(NSArray *sublayers, act::activity_storage_ref storage)
{
  for (ActWeekView_ActivityLayer *layer in sublayers)
    {
      const std::vector<act::activity_ref> &vec = layer.activities;
      if (std::any_of(vec.begin(), vec.end(),
		      [=] (act::activity_ref a) {
			return a->storage() == storage;}))
	return layer;
    }

  return nil;
}

- (ActWeekView_ActivityLayer *)activityLayerForStorage:
    (const act::activity_storage_ref)storage
{
  if (storage == nullptr)
    return nil;

  int week = [_controller weekForActivityStorage:storage];

  ActWeekView_GroupLayer *glayer = [self groupLayerForWeek:week];
  if (glayer == nil)
    return nil;

  ActWeekView_ActivityLayer *layer
    = activityLayerForStorage(glayer.sublayers, storage);
  if (layer == nil)
    return nil;

  ActWeekView_ActivityGroupLayer *aglayer = layer.groupLayer;
  if (aglayer != nil)
    layer = activityLayerForStorage(aglayer.sublayers, storage);

  return layer;
}

- (void)invalidateActivityStorage:(const act::activity_storage_ref)storage
{
  [[self activityLayerForStorage:storage] setNeedsLayout];
}

- (void)updateFrameSize
{
  NSRect frame = self.frame;
  CGFloat h = ROW_HEIGHT * _weekRange.length;

  if (frame.size.height != h)
    {
      [self setFrameSize:NSMakeSize(frame.size.width, h)];
      [self flashScrollersIfNeeded];
    }

  NSRect bounds = self.bounds;

  if (_trackingArea == nil
      || !NSEqualRects(bounds, _trackingArea.rect))
    {
      [self removeTrackingArea:_trackingArea];
      _trackingArea = [[NSTrackingArea alloc] initWithRect:bounds
		       options:(NSTrackingMouseEnteredAndExited
				| NSTrackingMouseMoved
				| NSTrackingActiveInKeyWindow)
		       owner:self userInfo:nil];
      [self addTrackingArea:_trackingArea];
    }
}

- (void)updateLayersForRect:(NSRect)rect
{
  NSRect bounds = self.bounds;

  int y0 = floor((rect.origin.y - bounds.origin.y) / ROW_HEIGHT);
  int y1 = ceil((rect.origin.y + rect.size.height - bounds.origin.y) / ROW_HEIGHT);
  if (y0 < 0) y0 = 0;
  if (y1 < 0) y1 = 0;

  CGFloat backing_scale = self.window.backingScaleFactor;
  CGFloat interface_scale = _controller.interfaceScale;

  CALayer *layer = self.layer;
  NSMutableArray *old_sublayers = [layer.sublayers mutableCopy];
  NSMutableArray *new_sublayers = [[NSMutableArray alloc] init];

  const auto &activities = _controller.controller.activityList;

  int week_idx = _weekRange.location + (_weekRange.length - (y0 + 1));

  _controller.headerView.weekIndex = week_idx;

  time_t week_date = act::week_date(week_idx);

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
	  if (tem.date == week_date)
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
	  sublayer.date = week_date;
	  sublayer.delegate = _controller;
	}
      
      sublayer.frame = CGRectMake(bounds.origin.x + LEFT_BORDER,
		bounds.origin.y + ROW_HEIGHT * y, bounds.size.width
		- floor((LEFT_BORDER + RIGHT_BORDER * interface_scale)),
		ROW_HEIGHT);
      sublayer.contentsScale = backing_scale;

      [new_sublayers addObject:sublayer];

      std::vector<act::database::item> week_vec;
      while (item != activities.cend() && !(item->date() < week_date))
	week_vec.push_back(*item++);

      sublayer.items = week_vec;
      sublayer.interfaceScale = interface_scale;
      [sublayer setNeedsLayout];

      week_date = week_date - SECONDS_PER_WEEK;
    }

  layer.sublayers = new_sublayers;

}

- (void)updateSelectionState
{
  act::activity_storage_ref storage
    = _controller.controller.selectedActivityStorage;

  ActWeekView_ActivityLayer *selected_layer
    = [self activityLayerForStorage:storage];

  if (_selectedLayer != selected_layer)
    {
      [_selectedLayer setNeedsLayout];
      _selectedLayer = selected_layer;
      [_selectedLayer setNeedsLayout];
    }
}

- (void)setSelectedLayer:(ActWeekView_ActivityLayer *)layer
{
  if (_selectedLayer != layer)
    {
      [_selectedLayer setNeedsLayout];
      _selectedLayer = layer;
    }
}

- (BOOL)wantsUpdateLayer
{
  return YES;
}

- (void)layout
{
  [self updateFrameSize];
}

- (void)updateLayer
{
  [self updateSelectionState];
  [self updateLayersForRect:self.visibleRect];
}

- (BOOL)isFlipped
{
  return YES;
}

- (BOOL)isOpaque
{
  return YES;
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
      switch ([chars characterAtIndex:0])
	{
	case NSLeftArrowFunctionKey:
	  [_controller.controller nextActivity:_controller];
	  return;

	case NSRightArrowFunctionKey:
	  [_controller.controller previousActivity:_controller];
	  return;

	case NSHomeFunctionKey:
	  [_controller.controller firstActivity:_controller];
	  return;

	case NSEndFunctionKey:
	  [_controller.controller lastActivity:_controller];
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
  NSPoint p = [self.superview convertPoint:e.locationInWindow fromView:nil];

  CALayer *self_layer = self.layer;
  CALayer *layer = [self_layer hitTest:NSPointToCGPoint(p)];

  act::activity_ref selection;

  while (layer != nil && layer != self_layer)
    {
      if ([layer isKindOfClass:[ActWeekView_ActivityLayer class]])
	{
	  ActWeekView_ActivityLayer *a_layer = (id)layer;
	  const std::vector<act::activity_ref> &vec = a_layer.activities;

	  if (vec.size() == 1)
	    {
	      selection = vec[0];
	      break;
	    }
	}

      layer = layer.superlayer;
    }

  _controller.controller.selectedActivityStorage
    = selection ? selection->storage() : nullptr;

  self.highlitLayer = nil;
}

- (void)mouseMoved:(NSEvent *)e
{
  NSPoint p = [self.superview convertPoint:e.locationInWindow fromView:nil];

  CALayer *self_layer = self.layer;
  CALayer *layer = [self_layer hitTest:NSPointToCGPoint(p)];
  ActWeekView_ActivityLayer *highlit_layer = nil;
  ActWeekView_ActivityLayer *expanded_layer = nil;

  while (layer != nil && layer != self_layer)
    {
      if ([layer isKindOfClass:[ActWeekView_ActivityLayer class]])
	{
	  if (highlit_layer == nil
	      && ((ActWeekView_ActivityLayer *)layer).activities.size() == 1)
	    {
	      highlit_layer = (ActWeekView_ActivityLayer *)layer;
	    }

	  if (((ActWeekView_ActivityLayer *)layer).expandable)
	    {
	      expanded_layer = (ActWeekView_ActivityLayer *)layer;
	      break;
	    }
	}

      layer = layer.superlayer;
    }

  self.expandedLayer = expanded_layer;
  self.highlitLayer = highlit_layer;
}

- (void)setExpandedLayer:(ActWeekView_ActivityLayer *)layer
{
  if (_expandedLayer != layer)
    {
      _expandedLayer.expanded = NO;
      _expandedLayer = layer;
      _expandedLayer.expanded = YES;
    }
}

- (void)setHighlitLayer:(ActWeekView_ActivityLayer *)layer
{
  if (_highlitLayer != layer)
    {
      _highlitLayer.highlit = NO;
      _highlitLayer = layer;
      _highlitLayer.highlit = YES;

      [NSRunLoop cancelPreviousPerformRequestsWithTarget:self
       selector:@selector(updatePopover) object:nil];
      [_controller.controller hidePopover];

      if (_highlitLayer != nil)
	{
	  [self performSelector:@selector(updatePopover) withObject:nil
	   afterDelay:.25];
	}
    }
}

- (void)updatePopover
{
  if (_highlitLayer != nil && _highlitLayer.activities.size() == 1)
    {
      const act::activity_ref &a = _highlitLayer.activities.front();
      NSRect r = NSRectFromCGRect([self.layer convertRect:_highlitLayer.bounds
				   fromLayer:_highlitLayer]);
      r = NSInsetRect(r, -2, -2);

      [_controller.controller showPopoverWithActivityStorage:a->storage()
       relativeToRect:r ofView:self preferredEdge:NSMaxYEdge];
    }
  else
    [_controller.controller hidePopover];
}

- (void)mouseExited:(NSEvent *)e
{
  if (_expandedLayer != nil)
    {
      _expandedLayer.expanded = NO;
      _expandedLayer = nil;
    }

  if (_highlitLayer != nil)
    {
      _highlitLayer.highlit = NO;
      _highlitLayer = nil;
      [self updatePopover];
    }
}

@end

@implementation ActWeekHeaderView

@synthesize controller = _controller;
@synthesize weekIndex = _weekIndex;

- (void)setWeekIndex:(int)idx
{
  if (_weekIndex != idx)
    {
      _weekIndex = idx;
      self.needsDisplay = YES;
    }
}

- (void)drawRect:(NSRect)r
{
  static NSDateFormatter *date_formatter;
  static NSDictionary *month_attrs;
  static NSDictionary *day_attrs;
  static NSColor *separator_color;
  static dispatch_once_t once;

  dispatch_once(&once, ^
    {
      NSLocale *locale = ((ActAppDelegate *)NSApp.delegate).currentLocale;

      date_formatter = [[NSDateFormatter alloc] init];
      date_formatter.locale = locale;
      date_formatter.dateFormat =
       [NSDateFormatter dateFormatFromTemplate:@"MMMyyyy" options:0
	locale:locale];

      NSColor *greyColor = [ActColor controlTextColor];

      NSMutableParagraphStyle *centerStyle
        = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
      centerStyle.alignment = NSCenterTextAlignment;

      month_attrs = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:HEADER_MONTH_FONT_SIZE],
	NSForegroundColorAttributeName: greyColor,
      };

      day_attrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:HEADER_DAY_FONT_SIZE],
	NSForegroundColorAttributeName: greyColor,
	NSParagraphStyleAttributeName: centerStyle,
      };

      separator_color = [NSColor colorWithDeviceWhite:.80 alpha:1];
    });

  NSRect bounds = self.bounds;
  CGFloat scale = _controller.interfaceScale;
  NSRect subR;

  // draw month name

  subR.origin.x = bounds.origin.x + LEFT_BORDER;
  subR.origin.y = bounds.origin.y + HEADER_MONTH_Y;
  subR.size.width = STATS_WIDTH + COLUMN_SPACING;
  subR.size.height = HEADER_MONTH_HEIGHT;

  time_t date = act::week_date(_weekIndex);

  [[date_formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:date]]
   drawInRect:subR withAttributes:month_attrs];

  // draw days of week

  CGFloat dlx = bounds.origin.x + LEFT_BORDER + STATS_WIDTH + COLUMN_SPACING;
  CGFloat drx = bounds.origin.x + bounds.size.width - (RIGHT_BORDER * scale);
  CGFloat dw = floor((drx - dlx) / (CGFloat)7);

  subR.origin.y = bounds.origin.y + HEADER_DAY_Y;
  subR.size.height = HEADER_DAY_HEIGHT;

  int start_of_week = act::shared_config().start_of_week();

  for (int i = 0; i < 7; i++)
    {
      subR.origin.x = dlx + dw * i;
      subR.size.width = dw;

      int di = (i + start_of_week) % 7;
      [date_formatter.shortWeekdaySymbols[di]
       drawInRect:subR withAttributes:day_attrs];
    }

  // draw separator

  subR.origin.x = bounds.origin.x;
  subR.origin.y = bounds.origin.y;
  subR.size.width = bounds.size.width;
  subR.size.height = 1;

  [separator_color setFill];
  [NSBezierPath fillRect:subR];
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

- (void)updateActivities
{
  if (_activities.size() != _items.size())
    {
      _activities.resize(_items.size());
    }

  for (size_t i = 0; i < _items.size(); i++)
    {
      if (!_activities[i] || _activities[i]->storage() != _items[i].storage())
	_activities[i].reset(new act::activity(_items[i].storage()));
    }
}

- (void)layoutSublayers
{
  if (_statsLayer == nil)
    {
      _statsLayer = [ActWeekView_StatsLayer layer];
      _statsLayer.delegate = self.delegate;
      [self addSublayer:_statsLayer];
    }

  if (_groupLayer == nil)
    {
      _groupLayer = [ActWeekView_GroupLayer layer];
      _groupLayer.delegate = self.delegate;
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

  CGRect bounds = self.bounds;
  int displayMode = ((ActWeekViewController *)self.delegate).displayMode;

  _statsLayer.date = _date;
  _statsLayer.displayMode = displayMode;
  _statsLayer.distance = distance;
  _statsLayer.duration = duration;
  _statsLayer.points = points;
  CGRect sr = CGRectMake(bounds.origin.x, bounds.origin.y,
			 STATS_WIDTH, bounds.size.height);
  sr = CGRectInset(sr, STATS_X_INSET, STATS_Y_INSET);
  _statsLayer.frame = sr;
  _statsLayer.contentsScale = self.contentsScale;

  _groupLayer.interfaceScale = self.interfaceScale;
  _groupLayer.date = _date;
  _groupLayer.activities = _activities;
  _groupLayer.displayMode = displayMode;
  CGFloat xoff = STATS_WIDTH + COLUMN_SPACING;
  _groupLayer.frame = CGRectMake(bounds.origin.x + xoff,
	bounds.origin.y, bounds.size.width - xoff, bounds.size.height);
  _groupLayer.contentsScale = self.contentsScale;
}

@end

@implementation ActWeekView_StatsLayer

+ (id)defaultValueForKey:(NSString *)key
{
  if ([key isEqualToString:@"wrapped"])
    return @YES;
  if ([key isEqualToString:@"opaque"])
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
      NSLocale *locale = ((ActAppDelegate *)NSApp.delegate).currentLocale;

      date_formatter = [[NSDateFormatter alloc] init];
      date_formatter.locale = locale;
      date_formatter.dateFormat
        = [NSDateFormatter dateFormatFromTemplate:@"dMMM" options:0
	   locale:locale];

      NSColor *greyColor = [ActColor controlTextColor];
      NSColor *redColor = [ActColor controlDetailTextColor];

      date_attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
		    [NSFont systemFontOfSize:STATS_DATE_FONT_SIZE],
		    NSFontAttributeName,
		    greyColor, NSForegroundColorAttributeName,
		    nil];
      main_attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
		    [ActFont mediumSystemFontOfSize:STATS_MAIN_FONT_SIZE],
		    NSFontAttributeName,
		    redColor, NSForegroundColorAttributeName,
		    nil];
      sub_attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
		    [NSFont systemFontOfSize:STATS_SUB_FONT_SIZE],
		    NSFontAttributeName,
		    greyColor, NSForegroundColorAttributeName,
		    nil];

      unichar c = 0x2013;
      en_dash = [[NSString alloc] initWithCharacters:&c length:1];
    });

  time_t start_date = _date;
  time_t end_date = _date + SECONDS_PER_WEEK;

  NSString *date_str = [NSString stringWithFormat:@"%@%@%@\n",
			[date_formatter stringFromDate:
			 [NSDate dateWithTimeIntervalSince1970:start_date]],
			en_dash,
			[date_formatter stringFromDate:
			 [NSDate dateWithTimeIntervalSince1970:end_date]]];

  size_t date_len = date_str.length;

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
		   @(rest.c_str())];

  NSMutableAttributedString *astr = [[NSMutableAttributedString alloc]
				     initWithString:str];

  [astr setAttributes:date_attrs range:NSMakeRange(0, date_len)];
  [astr setAttributes:main_attrs range:NSMakeRange(date_len, main_len)];
  [astr setAttributes:sub_attrs range:NSMakeRange(date_len + main_len, sub_len)];

  self.string = astr;
}

- (void)drawInContext:(CGContextRef)ctx
{
  CGContextSetFillColorWithColor(ctx, [ActColor midControlBackgroundColor].CGColor);
  CGContextFillRect(ctx, self.bounds);
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

- (const std::vector<act::activity_ref> &)activities
{
  return _activities;
}

- (void)setActivities:(const std::vector<act::activity_ref> &)vec
{
  if (_activities != vec)
    {
      _activities = vec;
      [self setNeedsLayout];
    }
}

- (void)layoutSublayers
{
  NSMutableArray *old_sublayers = [self.sublayers mutableCopy];
  NSMutableArray *new_sublayers = [[NSMutableArray alloc] init];

  CGRect bounds = self.bounds;
  CGFloat item_width = floor(bounds.size.width / 7);

  ssize_t item_i = _activities.size() - 1;
  time_t day_date = _date;

  for (int i = 0; i < 7; i++)
    {
      ActWeekView_ActivityLayer *sublayer = nil;

      NSInteger old_idx = 0;
      for (ActWeekView_ActivityLayer *tem in old_sublayers)
	{
	  if (tem.date == day_date)
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
	  sublayer.date = day_date;
	  [sublayer setExpandable:YES];
	  sublayer.delegate = self.delegate;
	}

      CGFloat px = bounds.origin.x + floor(i * item_width + item_width * .5);
      CGFloat py = bounds.origin.y + floor(ROW_HEIGHT * .5);

      [CATransaction animationBlock:^
        {
	  sublayer.position = CGPointMake(px, py);
	}];

      sublayer.contentsScale = self.contentsScale;

      [new_sublayers addObject:sublayer];

      time_t next_day_date = day_date + SECONDS_PER_DAY;

      std::vector<act::activity_ref> day_vec;
      while (item_i >= 0 && (_activities[item_i]->date() < next_day_date))
	{
	  day_vec.push_back(_activities[item_i]);
	  item_i--;
	}

      sublayer.activities = day_vec;
      sublayer.displayMode = self.displayMode;
      sublayer.interfaceScale = self.interfaceScale;

      day_date = next_day_date;
    }

  self.sublayers = new_sublayers;

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
  else if ([key isEqualToString:@"shadowOffset"])
    return [NSValue valueWithSize:NSZeroSize];
  else if ([key isEqualToString:@"shadowRadius"])
    return @6;
  else if ([key isEqualToString:@"shadowPathIsBounds"])
    return @YES;

  return [super defaultValueForKey:key];
}

- (const std::vector<act::activity_ref> &)activities
{
  return _activities;
}

- (void)setActivities:(const std::vector<act::activity_ref> &)vec
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

- (BOOL)isHighlit
{
  return _highlit;
}

- (void)setHighlit:(BOOL)flag
{
  if (_highlit != flag)
    {
      _highlit = flag;
      [self setNeedsLayout];
    }
}

- (void)layoutSublayers
{
  ActWeekViewController *controller = (ActWeekViewController *)self.delegate;

  double dist = 0, dur = 0, pts = 0;
  for (const auto &it : _activities)
    {
      dist += it->distance();
      dur += it->duration();
      pts += it->points();
    }

  /* FIXME: having the layer notify the view when it's selected is a
     kludge, but we need to handle layers being added and removed, and
     not existing when -updateLayersForRect: runs. */

  BOOL selected = NO;
  if (_activities.size() == 1
      && (_activities.front()->storage()
	  == controller.controller.selectedActivityStorage))
    {
      selected = YES;
      [controller.listView setSelectedLayer:self];
    }

  CGFloat scale = self.interfaceScale;

  CGFloat radius = activity_radius(dist, dur, pts, self.displayMode);
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
    color = [ActColor activityColor:*_activities[0].get()];
  else
    color = [NSColor colorWithDeviceWhite:.5 alpha:1];

  NSColor *background_color = nil;
  if (_activities.size() == 1)
    background_color = [color blendedColorWithFraction:.6 ofColor:[NSColor whiteColor]];
  else
    background_color = [NSColor colorWithDeviceWhite:.85 alpha:1];

  [CATransaction animationBlock:^
    {
      self.bounds = CGRectMake(0, 0, radius*2, radius*2);
      self.cornerRadius = radius;
      self.backgroundColor = background_color.CGColor;
      self.borderColor = color.CGColor;
      self.borderWidth = selected ? 5 : _activities.size() == 1 ? 1 : 0;
      self.shadowOpacity = _highlit ? 1 : 0;
    }];

  if (_highlit)
    self.shadowColor = color.CGColor;

  self.zPosition = _expanded ? 1 : 0;

  if (_activities.size() > 1)
    {
      if (_groupLayer == nil)
	{
	  _groupLayer = [ActWeekView_ActivityGroupLayer layer];
	  _groupLayer.delegate = self.delegate;
	  [self addSublayer:_groupLayer];
	}

      _groupLayer.interfaceScale = scale;
      _groupLayer.activities = _activities;
      _groupLayer.displayMode = self.displayMode;
      _groupLayer.expanded = _expanded;
      _groupLayer.frame = self.bounds;
    }
  else if (_groupLayer != nil)
    {
      [_groupLayer removeFromSuperlayer];
      _groupLayer = nil;
    }
}

@end

@implementation ActWeekView_ActivityGroupLayer

- (const std::vector<act::activity_ref> &)activities
{
  return _activities;
}

- (void)setActivities:(const std::vector<act::activity_ref> &)vec
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
  NSArray *sublayers = [NSArray arrayWithArray:self.sublayers];
  size_t count = sublayers.count;

  while (count > _activities.size())
    {
      [sublayers[count-1] removeFromSuperlayer];
      count--;
    }

  CGRect bounds = self.bounds;

  CGFloat cx = bounds.origin.x + floor(bounds.size.width * .5);
  CGFloat cy = bounds.origin.y + floor(bounds.size.height * .5);

  double ang_step = (2 * M_PI) / _activities.size();

  CGFloat scale = self.interfaceScale;

  for (size_t i = 0; i < _activities.size(); i++)
    {
      ActWeekView_ActivityLayer *sublayer = nil;

      if (i < count)
	sublayer = sublayers[i];
      else
	{
	  sublayer = [ActWeekView_ActivityLayer layer];
	  sublayer.delegate = self.delegate;
	  [self addSublayer:sublayer];
	}

      double dist = _activities[i]->distance();
      double dur = _activities[i]->duration();
      double pts = _activities[i]->points();

      CGFloat radius = activity_radius(dist, dur, pts, self.displayMode);
      radius = round(radius * scale);
      CGFloat ang = i * ang_step + M_PI;
      CGFloat hyp = bounds.size.width * .5 - radius * (_expanded ? .4 : 1);
      CGFloat px = cx + sin(ang) * hyp;
      CGFloat py = cy + cos(ang) * hyp;

      [CATransaction animationBlock:^
        {
	  sublayer.position = CGPointMake(px, py);
	}];

      sublayer.interfaceScale = scale;
      sublayer.displayMode = self.displayMode;
      sublayer.contentsScale = self.contentsScale;

      std::vector<act::activity_ref> day_vec;
      day_vec.push_back(_activities[i]);

      sublayer.activities = day_vec;
    }
}

@end
