// -*- c-style: gnu -*-

#import <AppKit/NSColor.h>

@interface ActColor : NSColor

+ (NSColor *)controlTextColor;
+ (NSColor *)disabledControlTextColor;
+ (NSColor *)controlTextColor:(BOOL)disabled;

+ (NSColor *)controlDetailTextColor;
+ (NSColor *)disabledControlDetailTextColor;
+ (NSColor *)controlDetailTextColor:(BOOL)disabled;

+ (NSColor *)controlBackgroundColor;
+ (NSArray *)controlAlternatingRowBackgroundColors;

@end
