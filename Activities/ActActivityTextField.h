// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

@class ActActivityViewController;

@interface ActActivityTextField : NSTextField

@property(nonatomic, assign) IBOutlet ActActivityViewController *controller;
@property(nonatomic) BOOL completesEverything;

@end


@interface ActExpandableTextField : ActActivityTextField
@end


@interface ActActivityFieldEditor : NSTextView
{
  BOOL _autoCompletes;
  BOOL _completesEverything;
  int _completionDepth;
}

@property(nonatomic) BOOL autoCompletes;
@property(nonatomic) BOOL completesEverything;

@end

