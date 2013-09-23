// -*- c-style: gnu -*-

#import "ActActivityTextField.h"

#import "ActActivityViewController.h"
#import "ActHorizontalBoxView.h"

#import <algorithm>

@interface ActActivityTextFieldCell : NSTextFieldCell
{
  ActActivityViewController *_controller;
  BOOL _completesEverything;
}

@property(nonatomic, assign) ActActivityViewController *controller;
@property(nonatomic) BOOL completesEverything;

@end


@implementation ActActivityTextField

+ (Class)cellClass
{
  return [ActActivityTextFieldCell class];
}

- (BOOL)becomeFirstResponder
{
  BOOL ret = [super becomeFirstResponder];

  if (ret)
    {
      // didBeginEditing doesn't happen until the first change is made,
      // which fails if the view is entered then completion key is typed
      // before anything is changed. So use this.

      [[[[self cell] controller] fieldEditor]
       setCompletesEverything:[[self cell] completesEverything]];
    }

  return ret;
}

- (void)setController:(ActActivityViewController *)obj
{
  [[self cell] setController:obj];
}

- (ActActivityViewController *)controller
{
  return [[self cell] controller];
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

  return width;
}

- (void)textDidChange:(NSNotification *)notification
{
  [super textDidChange:notification];

  ActHorizontalBoxView *box = (id) [self superview];
  if ([box isKindOfClass:[ActHorizontalBoxView class]])
    [box layoutSubviews];
}

@end


@implementation ActActivityTextFieldCell

@synthesize controller = _controller;

- (NSTextView *)fieldEditorForView:(NSView *)view
{
  return [_controller fieldEditor];
}

@end

@implementation ActActivityFieldEditor

@synthesize completesEverything = _completesEverything;

- (NSRange)rangeForUserCompletion
{
  NSArray *ranges = [self selectedRanges];
  if ([ranges count] < 1)
    return NSMakeRange(NSNotFound, 0);

  NSRange range = [[ranges objectAtIndex:0] rangeValue];
  if (range.length > 0)
    return range;

  if (_completesEverything)
    return NSMakeRange(0, range.location);
  else
    return [super rangeForUserCompletion];
}

@end
