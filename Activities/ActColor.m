// -*- c-style: gnu -*-

#import "ActColor.h"

@implementation ActColor

+ (NSColor *)controlTextColor
{
  static NSColor *color;

  if (color == nil)
    color = [[NSColor colorWithDeviceWhite:.25 alpha:1] retain];

  return color;
}

+ (NSColor *)disabledControlTextColor
{
  static NSColor *color;

  if (color == nil)
    color = [[NSColor colorWithDeviceWhite:.45 alpha:1] retain];

  return color;
}

+ (NSColor *)controlTextColor:(BOOL)disabled
{
  return !disabled ? [self controlTextColor] : [self disabledControlTextColor];
}

+ (NSColor *)controlDetailTextColor
{
  static NSColor *color;

  if (color == nil)
    {
      color = [[NSColor colorWithDeviceRed:197/255. green:56/255.
		blue:51/255. alpha:1] retain];
    }

  return color;
}

+ (NSColor *)disabledControlDetailTextColor
{
  static NSColor *color;

  if (color == nil)
    {
      color = [[NSColor colorWithDeviceRed:197/255. green:121/255.
		blue:118/255. alpha:1] retain];
    }

  return color;
}

+ (NSColor *)controlDetailTextColor:(BOOL)disabled
{
  return !disabled ? [self controlDetailTextColor] : [self disabledControlDetailTextColor];
}

+ (NSColor *)controlBackgroundColor
{
  static NSColor *color;

  if (color == nil)
    color = [[NSColor colorWithDeviceWhite:.98 alpha:1] retain];

  return color;
}

+ (NSArray *)controlAlternatingRowBackgroundColors
{
  static NSArray *colors;

  if (colors == nil)
    {
      colors = [[NSArray alloc] initWithObjects:
		[self controlBackgroundColor],
		[NSColor colorWithDeviceWhite:.94 alpha:1],
		nil];
    }

  return colors;
}

@end
