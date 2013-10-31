// -*- c-style: gnu -*-

#import "ActCollapsibleView.h"

#import "ActColor.h"
#import "ActViewLayout.h"

#define SPACING 3
#define DIS_SIZE 20
#define MIN_HEIGHT 20

#define TITLE_FONT_SIZE 11
#define TITLE_HEIGHT 16

@implementation ActCollapsibleView

@synthesize delegate = _delegate;
@synthesize headerView = _headerView;
@synthesize headerInset = _headerInset;
@synthesize contentView = _contentView;

static NSDictionary *_titleAttrs;

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self == nil)
    return nil;

  NSRect r = NSMakeRect(0, 0, DIS_SIZE, DIS_SIZE);
  _disclosureButton = [[NSButton alloc] initWithFrame:r];
  [_disclosureButton setButtonType:NSPushOnPushOffButton];
  [_disclosureButton setBezelStyle:NSDisclosureBezelStyle];
  [_disclosureButton setTitle:nil];
  [_disclosureButton highlight:NO];
  [_disclosureButton setState:NSOnState];
  [_disclosureButton setTarget:self];
  [_disclosureButton setAction:@selector(controlAction:)];
  [self addSubview:_disclosureButton];
  [_disclosureButton release];

  if (_titleAttrs == nil)
    {
      _titleAttrs = [[NSDictionary alloc] initWithObjectsAndKeys:
		     [NSFont fontWithName:@"Helvetica Neue Bold"
		      size:TITLE_FONT_SIZE],
		     NSFontAttributeName,
		     [ActColor controlTextColor],
		     NSForegroundColorAttributeName,
		     nil];
    }

  _titleSize = NSZeroSize;

  return self;
}

- (void)dealloc
{
  [_title release];

  [super dealloc];
}

- (BOOL)isCollapsed
{
  return ![_disclosureButton state];
}

- (void)setCollapsed:(BOOL)flag
{
  if ([_disclosureButton state] != !flag)
    {
      [_disclosureButton setState:!flag];
      [self controlAction:_disclosureButton];
    }
}

- (NSString *)title
{
  return _title;
}

- (void)setTitle:(NSString *)title
{
  if (_title != title)
    {
      [_title release];
      _title = [title copy];
      _titleSize = [_title sizeWithAttributes:_titleAttrs];

      [super subviewNeedsLayout:self];

      // FIXME: only invalidate title rect
      [self setNeedsDisplay:YES];
    }
}

static CGFloat
callHeightForWidth(id delegate, NSView *view, CGFloat width)
{
  if ([delegate respondsToSelector:@selector(heightOfView:forWidth:)])
    return [delegate heightOfView:view forWidth:width];
  else
    return [view heightForWidth:width];
}

static void
callLayoutSubviews(id delegate, NSView *view)
{
  if ([delegate respondsToSelector:@selector(layoutSubviewsOfView:)])
    [delegate layoutSubviewsOfView:view];
  else
    [view layoutSubviews];
}

- (CGFloat)heightForWidth:(CGFloat)width
{
  CGFloat content_width = width - 2;

  CGFloat header_width = content_width - (DIS_SIZE + SPACING) - _headerInset;
  if (_titleSize.width > 0)
    header_width -= _titleSize.width + SPACING;

  CGFloat header_height;
  header_height = callHeightForWidth(_delegate, _headerView, header_width);

  if (header_height < MIN_HEIGHT)
    header_height = MIN_HEIGHT;

  if (![_disclosureButton state])
    return header_height;

  CGFloat content_height;
  content_height = callHeightForWidth(_delegate, _contentView, content_width);

  return header_height + SPACING + content_height;
}

- (void)layoutSubviews
{
  NSRect bounds = [self bounds];

  NSPoint p = NSMakePoint(bounds.origin.x, bounds.origin.y
			  + bounds.size.height - DIS_SIZE);
  [_disclosureButton setFrameOrigin:p];

  CGFloat content_width = bounds.size.width - 2;

  CGFloat header_width = content_width - (DIS_SIZE + SPACING) - _headerInset;
  if (_titleSize.width > 0)
    header_width -= _titleSize.width + SPACING;

  CGFloat header_height = 0;

  if (_headerView != nil)
    {
      if (header_width > 0)
	header_height = callHeightForWidth(_delegate, _headerView, header_width);

      CGFloat header_x = bounds.origin.x + DIS_SIZE + SPACING;
      if (_titleSize.width > 0)
	header_x += _titleSize.width + SPACING;

      CGFloat header_y = bounds.origin.y + bounds.size.height - header_height - 1;
      if (header_height < MIN_HEIGHT)
	header_y -= (MIN_HEIGHT - (int)header_height) >> 1;

      NSRect hr = NSMakeRect(header_x, header_y, header_width, header_height);
      [_headerView setFrame:hr];
      callLayoutSubviews(_delegate, _headerView);
    }

  if (header_height < MIN_HEIGHT)
    header_height = MIN_HEIGHT;

  CGFloat content_height = 0;
  if (_contentView != nil && [_disclosureButton state])
    {
      content_height = callHeightForWidth(_delegate, _contentView, content_width);
      if (content_height > bounds.size.width - (header_height + SPACING))
	content_height = bounds.size.width - (header_height + SPACING);
    }

  if (content_height > 0)
    {
      NSRect cr = NSMakeRect(bounds.origin.x + 1, bounds.origin.y + 1,
			     content_width, content_height);
      [_contentView setFrame:cr];
      callLayoutSubviews(_delegate, _contentView);
      [_contentView setHidden:NO];
    }
  else
    [_contentView setHidden:YES];

  // for -drawRect:

  _headerHeight = header_height;
  _contentHeight = content_height;
}

- (void)drawRect:(NSRect)rect
{
  // FIXME: better way to abstract this? Someone (AppKit or CA?) has
  // turned off font smoothing before calling -drawRect:, but since
  // we're drawing into an opaque view that will work fine, so turn
  // it back on for the length of this method call.

  CGContextRef ctx
    = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
  CGContextSaveGState(ctx);
  CGContextSetShouldSmoothFonts(ctx, true);

  NSRect bounds = [self bounds];

  NSColor *bg = [ActColor darkControlBackgroundColor];
  NSColor *dark = [NSColor colorWithDeviceWhite:.66 alpha:1];
  NSColor *light = [NSColor whiteColor];

  [bg setFill];
  [NSBezierPath fillRect:NSMakeRect(bounds.origin.x + 1,
				    bounds.origin.y + bounds.size.height
				    - _headerHeight, bounds.size.width - 2,
				    _headerHeight - 2)];

  [light setFill];
  [NSBezierPath fillRect:NSMakeRect(bounds.origin.x + 1,
				    bounds.origin.y + bounds.size.height - 2,
				    bounds.size.width - 2, 1)];

  [dark setStroke];
  [[NSBezierPath bezierPathWithRoundedRect:
    NSInsetRect(bounds, .5, .5) xRadius:3 yRadius:3] stroke];

  if (_titleSize.width > 0)
    {
      NSPoint p;
      p.x = bounds.origin.x + DIS_SIZE + SPACING;
      p.y = bounds.origin.y + bounds.size.height - _titleSize.height;
      [_title drawAtPoint:p withAttributes:_titleAttrs];
    }

  if ([_disclosureButton state] && _contentHeight > 0)
    {
      [dark setFill];
      [NSBezierPath fillRect:
       NSMakeRect(bounds.origin.x + 1, bounds.origin.y
		  + bounds.size.height - (_headerHeight + (SPACING - 1)),
		  bounds.size.width - 2, 1)];
    }

  CGContextRestoreGState(ctx);
}

- (void)mouseDown:(NSEvent *)e
{
  NSRect bounds = [self bounds];
  NSPoint p = [self convertPoint:[e locationInWindow] fromView:nil];

  if (p.y > bounds.origin.y + bounds.size.height - _headerHeight
      && [e clickCount] == 2)
    {
      [self setCollapsed:![self isCollapsed]];
    }
}

- (IBAction)controlAction:(id)sender
{
  if (sender == _disclosureButton)
    {
      [[self superview] subviewNeedsLayout:self];
    }
}

- (BOOL)autoresizesSubviews
{
  return NO;
}

@end
