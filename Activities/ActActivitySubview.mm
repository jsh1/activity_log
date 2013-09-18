// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

#import "ActActivityViewController.h"

@implementation ActActivitySubview

@synthesize controller = _controller;

- (void)drawBackgroundRect:(NSRect)r
{
  CGContextRef ctx = (CGContextRef) [[NSGraphicsContext
				      currentContext] graphicsPort];

  CGRect bounds = NSRectToCGRect([self bounds]);

  CGContextSaveGState(ctx);
  CGContextSetGrayFillColor(ctx, 1, 1);
  CGContextFillRect(ctx, bounds);
  CGContextRestoreGState(ctx);
}

@end

@implementation NSView (ActActivitySubview)

- (void)activityDidChange
{
  for (NSView *subview in [self subviews])
    [subview activityDidChange];
}

- (void)activityDidChangeField:(NSString *)name
{
  for (NSView *subview in [self subviews])
    [subview activityDidChangeField:name];
}

- (void)activityDidChangeBody
{
  for (NSView *subview in [self subviews])
    [subview activityDidChangeBody];
}

- (void)selectedLapDidChange
{
  for (NSView *subview in [self subviews])
    [subview selectedLapDidChange];
}

@end
