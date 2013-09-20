// -*- c-style: gnu -*-

#import "ActExpandableTextField.h"

#import "ActHorizontalBoxView.h"

#import <algorithm>

#define MIN_WIDTH 2

@implementation ActExpandableTextField

- (CGFloat)preferredWidth
{
  NSString *text = [self stringValue];

  if ([text length] == 0)
    text = [[self cell] placeholderString];

  CGFloat width = MIN_WIDTH;

  if ([text length] != 0)
    {
      NSDictionary *attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
			     [self font], NSFontAttributeName, nil];

      NSSize size = [text sizeWithAttributes:attrs];

      width = std::max(width, size.width + 3);

      [attrs release];
    }

  return width;
}

- (void)textDidChange:(NSNotification *)notification
{
  ActHorizontalBoxView *box = (id) [self superview];
  if (![box isKindOfClass:[ActHorizontalBoxView class]])
    return;

  [box layoutSubviews];
}

@end
