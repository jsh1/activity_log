// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

@class ActActivityView;

@interface ActActivityBodyView : NSView
{
@private
  IBOutlet NSTextView *_textView;
  IBOutlet ActActivityView *_activityView;

  NSLayoutManager *_layoutManager;
  NSTextContainer *_layoutContainer;
}

@property(nonatomic, assign) ActActivityView *activityView;

@property(nonatomic, copy) NSString *bodyString;

@end
