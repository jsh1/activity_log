/* -*- c-style: gnu -*-

   Copyright (c) 2015 John Harper <jsh@unfactored.org>

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

#import "ActFont.h"

#import <AppKit/AppKit.h>
#import <QuartzCore/CABase.h>

@implementation ActFont

+ (NSFont *)bodyFontOfSize:(CGFloat)size
{
  NSString *name = [[NSUserDefaults standardUserDefaults]
		    stringForKey:@"ActBodyFont"];

  return [self fontWithName:name size:size];
}

+ (NSFont *)mediumSystemFontOfSize:(CGFloat)size
{
#if CA_OS_VERSION(__MAC_10_11, __IPHONE_NA)
  return [NSFont systemFontOfSize:size weight:NSFontWeightMedium];
#else
  return [[NSFontManager sharedFontManager] convertWeight:YES
	  ofFont:[NSFont systemFontOfSize:size]];
#endif
}

@end
