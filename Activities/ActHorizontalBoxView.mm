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

#import "ActHorizontalBoxView.h"

@implementation ActHorizontalBoxView

- (CGFloat)heightForWidth:(CGFloat)w
{
  CGFloat h = 0;

  for (NSView *subview in [self subviews])
    {
      CGFloat hh = [subview frame].size.height;
      if (h < hh)
	h = hh;
    }

  return h;
}

- (void)layoutSubviews
{
  NSRect bounds = [self bounds];
  CGFloat x = 0;

  for (NSView *subview in [self subviews])
    {
      CGFloat w = [subview preferredWidth];

      NSRect old_frame = [subview frame];

      NSRect new_frame;
      if (!_rightToLeft)
	new_frame.origin.x = bounds.origin.x + x;
      else
	new_frame.origin.x = bounds.origin.x + bounds.size.width - (x + w);
      new_frame.origin.y = old_frame.origin.y;
      new_frame.size.width = w;
      new_frame.size.height = old_frame.size.height;

      if (!NSEqualRects(old_frame, new_frame))
	[subview setFrame:new_frame];

      x += w + _spacing;
    }
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
  [self layoutSubviews];
}

@end

@implementation NSView (ActHorizontalBoxView)

- (CGFloat)preferredWidth
{
  return [self frame].size.width;
}

@end
