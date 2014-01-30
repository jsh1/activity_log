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

+ (UIColor *)tintColor
{
  return [self redTextColor];
}

+ (UIColor *)controlTextColor
{
  static UIColor *color;

  if (color == nil)
    color = [UIColor colorWithWhite:0 alpha:1];

  return color;
}

+ (UIColor *)disabledControlTextColor
{
  static UIColor *color;

  if (color == nil)
    color = [UIColor colorWithWhite:.45 alpha:1];

  return color;
}

+ (UIColor *)controlTextColor:(BOOL)disabled
{
  return !disabled ? [self controlTextColor] : [self disabledControlTextColor];
}

+ (UIColor *)redTextColor
{
  static UIColor *color;

  if (color == nil)
    color = [UIColor colorWithRed:1 green:60/255. blue:47/255. alpha:1];

  return color;
}

+ (UIColor *)blueTextColor
{
  static UIColor *color;

  if (color == nil)
    color = [UIColor colorWithRed:8/255. green:107/255. blue:1 alpha:1];

  return color;
}

+ (UIColor *)controlBackgroundColor
{
  static UIColor *color;

  if (color == nil)
    color = [UIColor colorWithHue:BG_HUE saturation:.01 brightness:.96 alpha:1];

  return color;
}

+ (UIColor *)darkControlBackgroundColor
{
  static UIColor *color;

  if (color == nil)
    color = [UIColor colorWithHue:BG_HUE saturation:.03 brightness:.91 alpha:1];

  return color;
}

+ (UIColor *)midControlBackgroundColor
{
  static UIColor *color;

  if (color == nil)
    color = [UIColor colorWithHue:BG_HUE saturation:.02 brightness:.935 alpha:1];

  return color;
}

+ (UIColor *)activityColor:(const act::activity &)activity
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
	  if ([strings count] == 3)
	    {
	      CGFloat red = [[strings objectAtIndex:0] doubleValue];
	      CGFloat green = [[strings objectAtIndex:1] doubleValue];
	      CGFloat blue = [[strings objectAtIndex:2] doubleValue];
	      UIColor *c = [UIColor colorWithRed:red green:green blue:blue alpha:1];
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

  UIColor *c = colors[[NSString stringWithUTF8String:type.c_str()]];
  if (c == nil)
    c = [UIColor colorWithWhite:.5 alpha:1];

  return c;
}

@end
