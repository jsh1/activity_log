// -*- c-style: gnu -*-

#import "ActExpandableTextField.h"

#import "ActHorizontalBoxView.h"

#import <algorithm>

#define MIN_WIDTH 20

@implementation ActExpandableTextField

- (CGFloat)preferredWidth
{
  NSString *text = [self stringValue];
  if ([text length] == 0)
    text = [[self cell] placeholderString];

  CGFloat width = MIN_WIDTH;

  NSAttributedString *astr = [self attributedStringValue];

  if ([astr length] != 0)
    {
      NSDictionary *dict = [astr attributesAtIndex:0 effectiveRange:nil];
      NSSize size = [text sizeWithAttributes:dict];

      width = std::max(width, size.width + 10);
    }

  return width;
}

- (void)textDidBeginEditing:(NSNotification *)notification
{
  [self setDrawsBackground:YES];
}

- (void)textDidEndEditing:(NSNotification *)notification
{
  [self setDrawsBackground:NO];
}

- (void)textDidChange:(NSNotification *)notification
{
  ActHorizontalBoxView *box = (id) [self superview];
  if (![box isKindOfClass:[ActHorizontalBoxView class]])
    return;

  [box layoutSubviews];
}

@end
