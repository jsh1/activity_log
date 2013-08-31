// -*- c-style: gnu -*-

#import <Foundation/Foundation.h>

#import <string>

@interface NSString (ActFoundationExtensions)

- (void)copyStdString:(std::string &)s;
  
@end

@interface NSArray (ActFoundationExtensions)

- (NSInteger)indexOfStringNoCase:(NSString *)str;
- (BOOL)containsStringNoCase:(NSString *)str;

@end
