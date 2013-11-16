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

#import "ActTextField.h"

#import "ActHorizontalBoxView.h"
#import "ActViewLayout.h"
#import "ActWindowController.h"

#import <algorithm>

@interface ActTextFieldCell : NSTextFieldCell
{
  BOOL _completesEverything;
}

@property(nonatomic) BOOL completesEverything;

@end


@implementation ActTextField

+ (Class)cellClass
{
  return [ActTextFieldCell class];
}

- (ActFieldEditor *)actFieldEditor
{
  id<ActTextFieldDelegate> delegate = (id)[self delegate];

  if ([delegate respondsToSelector:@selector(actFieldEditor:)])
    return [delegate actFieldEditor:self];
  else
    return nil;
}

- (BOOL)becomeFirstResponder
{
  BOOL ret = [super becomeFirstResponder];

  if (ret)
    {
      // didBeginEditing doesn't happen until the first change is made,
      // which fails if the view is entered then completion key is typed
      // before anything is changed. So use this.

      BOOL flag = [[self cell] completesEverything];
      [[self actFieldEditor] setCompletesEverything:flag];
    }

  return ret;
}

- (void)setCompletesEverything:(BOOL)flag
{
  [[self cell] setCompletesEverything:flag];
}

- (BOOL)completesEverything
{
  return [[self cell] completesEverything];
}

@end


@implementation ActExpandableTextField

- (CGFloat)preferredWidth
{
  NSString *text = [self stringValue];

  if ([text length] == 0)
    text = [[self cell] placeholderString];

  CGFloat width = 2;

  if ([text length] != 0)
    {
      NSDictionary *attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
			     [self font], NSFontAttributeName, nil];

      NSSize size = [text sizeWithAttributes:attrs];

      width = std::max(width, size.width + 3);

      [attrs release];
    }

  return ceil(width);
}

- (void)textDidChange:(NSNotification *)notification
{
  [super textDidChange:notification];

  [[self superview] subviewNeedsLayout:self];
}

@end


@implementation ActTextFieldCell

@synthesize completesEverything = _completesEverything;

- (NSTextView *)fieldEditorForView:(NSView *)view
{
  if ([view isKindOfClass:[ActTextField class]])
    return [(ActTextField *)view actFieldEditor];
  else
    return nil;
}

@end

@implementation ActFieldEditor

@synthesize autoCompletes = _autoCompletes;
@synthesize completesEverything = _completesEverything;

+ (NSCharacterSet *)wordCharacters
{
  static NSMutableCharacterSet *set;

  if (set == nil)
    {
      set = [[NSMutableCharacterSet alloc] init];
      [set formUnionWithCharacterSet:
       [NSCharacterSet alphanumericCharacterSet]];
      [set addCharactersInString:@"-_"];
    }

  return set;
}

- (id)initWithFrame:(NSRect)rect
{
  _autoCompletes = YES;
  return [super initWithFrame:rect];
}

- (NSRange)rangeForUserCompletion
{
  NSArray *ranges = [self selectedRanges];
  if ([ranges count] < 1)
    return NSMakeRange(NSNotFound, 0);

  NSRange range = [[ranges objectAtIndex:0] rangeValue];
  if (range.length > 0 || range.location == 0)
    return range;

  if (_completesEverything)
    return NSMakeRange(0, range.location);

  NSInteger idx = range.location;
  NSString *str = [self string];
  NSCharacterSet *set = [[self class] wordCharacters];

  while (idx > 0 && [set characterIsMember:[str characterAtIndex:idx-1]])
    idx--;

  if (idx < range.location)
    return NSMakeRange(idx, range.location - idx);
  else
    return NSMakeRange(NSNotFound, 0);
}

// FIXME: hack. On 10.9 NSTextView's implementation of this method
// calls NSSpellChecker method with the same name, which seems to hang
// when called with a single-character range (times out on an RPC). So
// override this method to only invoke the delegate that actually
// generates our completions.

- (NSArray *)completionsForPartialWordRange:(NSRange)range
    indexOfSelectedItem:(NSInteger *)idx
{
  id delegate = [self delegate];

  if ([delegate respondsToSelector:
       @selector(textView:completions:forPartialWordRange:indexOfSelectedItem:)])
    {
      return [delegate textView:self completions:[NSArray array]
	      forPartialWordRange:range indexOfSelectedItem:idx];
    }
  else
    return [NSArray array];
}

- (void)didChangeText
{
  [super didChangeText];

  if (_autoCompletes && [[self string] length] != 0 && _completionDepth == 0)
    {
      _completionDepth++;

      @try
	{
	  [self complete:nil];
	} 
      @finally
	{
	  _completionDepth--;
	}
    }
}

@end
