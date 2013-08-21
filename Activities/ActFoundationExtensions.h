// -*- c-style: gnu -*-

#import <Foundation/Foundation.h>

#import <string>

@interface NSString (ActFoundationExtensions)

- (void)copyStdString:(std::string &)s;
  
@end
