// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

@interface ActActivityBodyView : ActActivitySubview <NSTextViewDelegate>
{
  IBOutlet NSTextView *_textView;

  NSLayoutManager *_layoutManager;
  NSTextContainer *_layoutContainer;
}

@property(nonatomic, copy) NSString *bodyString;

@end
