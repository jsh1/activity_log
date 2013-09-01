// -*- c-style: gnu -*-

#import "ActFoundationExtensions.h"

@implementation NSString (ActFoundationExtensions)

- (void)copyStdString:(std::string &)s
{
  s.append([self UTF8String]);
}

- (BOOL)isEqualToStringNoCase:(NSString *)str
{
  return [self compare:str options:NSCaseInsensitiveSearch] == NSOrderedSame;
}

@end

@implementation NSArray (ActFoundationExtensions)

- (NSInteger)indexOfStringNoCase:(NSString *)str1
{
  NSInteger idx = 0;

  for (NSString *str2 in self)
    {
      if ([str1 isEqualToStringNoCase:str2])
	return idx;
      idx++;
    }

  return NSNotFound;
}

- (BOOL)containsStringNoCase:(NSString *)str
{
  return [self indexOfStringNoCase:str] != NSNotFound;
}

@end
