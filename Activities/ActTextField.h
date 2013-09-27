// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

@interface ActTextField : NSTextField

@property(nonatomic) BOOL completesEverything;

@end


@interface ActExpandableTextField : ActTextField
@end


@interface ActFieldEditor : NSTextView
{
  BOOL _autoCompletes;
  BOOL _completesEverything;
  int _completionDepth;
}

@property(nonatomic) BOOL autoCompletes;
@property(nonatomic) BOOL completesEverything;

@end


@protocol ActTextFieldDelegate <NSTextFieldDelegate>
@optional

- (ActFieldEditor *)actFieldEditor:(ActTextField *)obj;

@end
