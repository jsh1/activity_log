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

#import "ActCollapsibleView.h"

#import "ActColor.h"
#import "ActViewLayout.h"

#define SPACING 3
#define DIS_SIZE 20
#define MIN_HEIGHT 20

#define TITLE_FONT_SIZE 11

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
  [_disclosureButton setTitle:@""];
  [_disclosureButton highlight:NO];
  [_disclosureButton setState:NSOnState];
  [_disclosureButton setTarget:self];
  [_disclosureButton setAction:@selector(controlAction:)];
  [self addSubview:_disclosureButton];
  [_disclosureButton release];

  if (_titleAttrs == nil)
    {
      _titleAttrs = [[NSDictionary alloc] initWithObjectsAndKeys:
		     [NSFont boldSystemFontOfSize:TITLE_FONT_SIZE],
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
  BOOL expanded = [_disclosureButton state] && _contentHeight > 0;

  NSColor *dark = [NSColor colorWithDeviceWhite:.75 alpha:1];

  [[ActColor darkControlBackgroundColor] setFill];
  [NSBezierPath fillRect:NSMakeRect(bounds.origin.x + 1,
				    bounds.origin.y + bounds.size.height
				    - _headerHeight - 1, bounds.size.width - 1,
				    _headerHeight)];

  [dark set];

  NSRect border = NSInsetRect(bounds, .5, .5);
  NSBezierPath *path = nil;
  if (!expanded)
    path = [NSBezierPath bezierPathWithRoundedRect:border xRadius:3 yRadius:3];
  else
    {
      CGFloat llx = border.origin.x;
      CGFloat lly = border.origin.y;
      CGFloat urx = llx + border.size.width;
      CGFloat ury = lly + border.size.height;
      CGFloat r = 3;

      path = [NSBezierPath bezierPath];
      [path moveToPoint:NSMakePoint(llx, lly)];
      [path lineToPoint:NSMakePoint(urx, lly)];
      [path appendBezierPathWithArcWithCenter:NSMakePoint(urx - r, ury - r)
       radius:r startAngle:0 endAngle:90 clockwise:NO];
      [path appendBezierPathWithArcWithCenter:NSMakePoint(llx + r, ury - r)
       radius:r startAngle:90 endAngle:180 clockwise:NO];
      [path closePath];

      [NSBezierPath fillRect:
       NSMakeRect(bounds.origin.x + 1, bounds.origin.y
		  + bounds.size.height - (_headerHeight + (SPACING - 1)),
		  bounds.size.width - 2, 1)];
    }
  [path stroke];

  if (_titleSize.width > 0)
    {
      NSPoint p;
      p.x = bounds.origin.x + DIS_SIZE + SPACING;
      p.y = (bounds.origin.y + bounds.size.height - _headerHeight
	     + (_headerHeight - _titleSize.height) * .5);
      [_title drawAtPoint:p withAttributes:_titleAttrs];
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
