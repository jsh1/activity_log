// -*- c-style: gnu -*-

#import "ActActivityViewController.h"

#import "ActChartViewController.h"
#import "ActCollapsibleView.h"
#import "ActHeaderViewController.h"
#import "ActLapViewController.h"
#import "ActMapViewController.h"
#import "ActSummaryViewController.h"
#import "ActViewLayout.h"
#import "ActWindowController.h"

#define MARGIN 10

@implementation ActActivityViewController

- (NSString *)viewNibName
{
  return @"ActActivityView";
}

- (id)initWithController:(ActWindowController *)controller
{
  self = [super initWithController:controller];
  if (self == nil)
    return nil;

  if (ActViewController *obj
      = [[ActSummaryViewController alloc] initWithController:_controller])
    {
      [self addSubviewController:obj];
      [obj release];
    }

  // FIXME: these should be configurable and persistent

  if (ActViewController *obj
      = [[ActHeaderViewController alloc] initWithController:_controller])
    {
      [self addSubviewController:obj];
      [obj release];
    }

  if (ActViewController *obj
      = [[ActMapViewController alloc] initWithController:_controller])
    {
      [self addSubviewController:obj];
      [obj release];
    }

  if (ActViewController *obj
      = [[ActChartViewController alloc] initWithController:_controller])
    {
      [self addSubviewController:obj];
      [obj release];
    }

  if (ActViewController *obj
      = [[ActLapViewController alloc] initWithController:_controller])
    {
      [self addSubviewController:obj];
      [obj release];
    }

  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  for (ActViewController *controller in [self subviewControllers])
    [_activityView addSubview:[controller view]];
}

- (NSDictionary *)savedViewState
{
  NSMutableDictionary *state
    = [NSMutableDictionary dictionaryWithDictionary:[super savedViewState]];

  NSMutableDictionary *collapsed = [NSMutableDictionary dictionary];

  for (ActViewController *controller in [self subviewControllers])
    {
      ActCollapsibleView *view = (id)[controller view];
      if ([view isKindOfClass:[ActCollapsibleView class]]
	  && [view isCollapsed])
	[collapsed setObject:@YES forKey:[controller identifier]];
    }

  [state setObject:collapsed forKey:@"ActViewCollapsed"];

  return state;
}

- (void)applySavedViewState:(NSDictionary *)state
{
  [super applySavedViewState:state];

  if (NSDictionary *dict = [state objectForKey:@"ActViewCollapsed"])
    {
      for (ActViewController *controller in [self subviewControllers])
	{
	  if (NSNumber *obj = [dict objectForKey:[controller identifier]])
	    [(ActCollapsibleView *)[controller view] setCollapsed:[obj boolValue]];
	}
    }
}

@end

@implementation ActActivityView

static CGFloat
layoutSubviews(ActActivityView *self, CGFloat width,
	       BOOL modifySubviews, BOOL updateHeight)
{
  NSRect bounds = [self bounds];
  CGFloat y = 0;

  if (width < 0)
    width = bounds.size.width - MARGIN*2;

  self->_ignoreLayout++;

  for (NSView *view in [self subviews])
    {
      CGFloat height = [view heightForWidth:width];

      if (y == 0)
	y += MARGIN;

      if (modifySubviews)
	{
	  NSRect frame;
	  frame.origin.x = bounds.origin.x + MARGIN;
	  frame.origin.y = bounds.origin.y + y;
	  frame.size.width = width;
	  frame.size.height = height;

	  if (!NSEqualRects(frame, [view frame]))
	    [view setFrame:frame];

	  [view layoutSubviews];
	}

      y += height + MARGIN;
    }

  if (updateHeight && bounds.size.height != y)
    {
      bounds.size.height = y;
      [self setFrameSize:bounds.size];
    }

  self->_ignoreLayout--;

  return y;
}

- (CGFloat)heightForWidth:(CGFloat)width
{
  return layoutSubviews(self, width, NO, NO);
}

- (void)subviewNeedsLayout:(NSView *)view
{
  // This view returns YES from -wantsUpdateLayer, so marking it for
  // redisplay will actually cause -updateLayer to be invoked before
  // drawing happens. This allows relayout to run once, rather many
  // times, and doesn't run until after all views have responded to
  // their notifications.

  [self setNeedsDisplay:YES];
}

- (void)layoutSubviews
{
  layoutSubviews(self, -1, YES, NO);
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
  if (_ignoreLayout == 0)
    layoutSubviews(self, -1, YES, YES);
}

- (BOOL)wantsUpdateLayer
{
  return YES;
}

- (void)updateLayer
{
  layoutSubviews(self, -1, YES, YES);
}

- (BOOL)isFlipped
{
  return YES;
}

@end
