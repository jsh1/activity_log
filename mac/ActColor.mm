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

#import "ActColor.h"

#define BG_HUE (202./360.)

@implementation ActColor

+ (NSColor *)controlTextColor
{
  static NSColor *color;

  if (color == nil)
    color = [NSColor colorWithDeviceWhite:.25 alpha:1];

  return color;
}

+ (NSColor *)disabledControlTextColor
{
  static NSColor *color;

  if (color == nil)
    color = [NSColor colorWithDeviceWhite:.45 alpha:1];

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
      color = [NSColor colorWithDeviceRed:197/255. green:56/255.
		blue:51/255. alpha:1];
    }

  return color;
}

+ (NSColor *)disabledControlDetailTextColor
{
  static NSColor *color;

  if (color == nil)
    {
      color = [NSColor colorWithDeviceRed:197/255. green:121/255.
		blue:118/255. alpha:1];
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
    color = [NSColor colorWithCalibratedHue:BG_HUE saturation:.01 brightness:.96 alpha:1];

  return color;
}

+ (NSColor *)darkControlBackgroundColor
{
  static NSColor *color;

  if (color == nil)
    color = [NSColor colorWithCalibratedHue:BG_HUE saturation:.03 brightness:.91 alpha:1];

  return color;
}

+ (NSColor *)midControlBackgroundColor
{
  static NSColor *color;

  if (color == nil)
    color = [NSColor colorWithCalibratedHue:BG_HUE saturation:.02 brightness:.935 alpha:1];

  return color;
}

+ (NSArray *)controlAlternatingRowBackgroundColors
{
  static NSArray *colors;

  if (colors == nil)
    {
      colors = [[NSArray alloc] initWithObjects:
		[self controlBackgroundColor],
		[self darkControlBackgroundColor],
		nil];
    }

  return colors;
}

+ (NSColor *)activityColor:(const act::activity &)activity
{
  static NSDictionary *colors;
  static dispatch_once_t once;

  dispatch_once(&once, ^
    {
      NSDictionary *strings = [[NSUserDefaults standardUserDefaults]
			       objectForKey:@"ActActivityColors"];
      NSMutableDictionary *dict = [NSMutableDictionary dictionary];

      for (NSString *name in strings)
	{
	  NSString *desc = strings[name];
	  NSArray *strings = [desc componentsSeparatedByCharactersInSet:
			      [NSCharacterSet whitespaceCharacterSet]];
	  if (strings.count == 3)
	    {
	      CGFloat red = [strings[0] doubleValue];
	      CGFloat green = [strings[1] doubleValue];
	      CGFloat blue = [strings[2] doubleValue];
	      NSColor *c = [NSColor colorWithDeviceRed:red green:green
			    blue:blue alpha:1];
	      dict[name] = c;
	    }
	}

      colors = [dict copy];
    });

  const std::string *type1 = activity.field_ptr("activity");
  const std::string *type2 = activity.field_ptr("type");

  std::string type;

  if (type1 != nullptr)
    type.append(*type1);
  if (type1 != nullptr && type2 != nullptr)
    type.push_back('/');
  if (type2 != nullptr)
    type.append(*type2);

  NSColor *c = colors[@(type.c_str())];
  if (c == nil)
    c = [NSColor colorWithDeviceWhite:.5 alpha:1];

  return c;
}

@end
