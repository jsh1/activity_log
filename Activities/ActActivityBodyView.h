// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

@class ActActivityView;

@interface ActActivityBodyView : NSView
{
@private
  IBOutlet NSText *_textView;
  IBOutlet ActActivityView *_activityView;
}

@property(nonatomic, assign) ActActivityView *activityView;

@property(nonatomic, copy) NSString *bodyString;

@end
