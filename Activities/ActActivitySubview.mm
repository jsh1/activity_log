// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

#import "ActActivityView.h"

@implementation ActActivitySubview

@synthesize activityView = _activityView;

+ (NSString *)nibName
{
  return nil;
}

+ (ActActivitySubview *)subviewForView:(ActActivityView *)view
{
  if (NSString *nibName = [self nibName])
    {
      NSArray *objects = nil;
      [[NSBundle mainBundle] loadNibNamed:nibName owner:nil
       topLevelObjects:&objects];

      // FIXME: autorelease contents of `objects'?

      for (id obj in objects)
	{
	  if ([obj isKindOfClass:[ActActivitySubview class]])
	    {
	      [(ActActivitySubview *)obj setActivityView:view];
	      return obj;
	    }
	}

      return nil;
    }
  else
    {
      ActActivitySubview *subview = [[self alloc] initWithFrame:NSZeroRect];
      [subview setActivityView:view];
      return [subview autorelease];
    }
}

- (void)activityDidChange
{
}

- (void)activityDidChangeField:(NSString *)name
{
}

- (void)activityDidChangeBody
{
}

- (void)selectedLapDidChange
{
}

- (NSEdgeInsets)edgeInsets
{
  return NSEdgeInsetsMake(0, 0, 0, 0);
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
  return [self bounds].size.height;
}

- (NSInteger)preferredNumberOfColumns
{
  return 0;
}

- (void)layoutSubviews
{
}

- (void)drawBackgroundRect:(NSRect)r
{
  CGContextRef ctx = (CGContextRef) [[NSGraphicsContext
				      currentContext] graphicsPort];

  CGRect bounds = NSRectToCGRect([self bounds]);

  CGContextSaveGState(ctx);
  CGContextSetGrayFillColor(ctx, .98, 1);
  CGContextFillRect(ctx, bounds);
  CGContextRestoreGState(ctx);
}

- (void)drawBorderRect:(NSRect)r
{
  CGContextRef ctx = (CGContextRef) [[NSGraphicsContext
				      currentContext] graphicsPort];

  CGRect bounds = NSRectToCGRect([self bounds]);

  CGContextSaveGState(ctx);
  CGContextSetGrayStrokeColor(ctx, .75, 1);
  CGContextStrokeRect(ctx, CGRectInset(bounds, .5, .5));
  CGContextRestoreGState(ctx);
}

@end
