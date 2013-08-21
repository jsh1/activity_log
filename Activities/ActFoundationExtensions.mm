// -*- c-style: gnu -*-

#import "ActFoundationExtensions.h"

@implementation NSString (ActFoundationExtensions)

- (void)copyStdString:(std::string &)s
{
  s.append([self UTF8String]);
}

@end
