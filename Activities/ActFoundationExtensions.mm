// -*- c-style: gnu -*-

#import "ActFoundationExtensions.h"

@implementation NSString (ActFoundationExtensions)

- (void)copyStdString:(std::string &)s
{
  s.append([self UTF8String]);
}

@end

@implementation NSArray (ActFoundationExtensions)

- (NSInteger)indexOfStringNoCase:(NSString *)str1
{
  NSInteger idx = 0;

  for (NSString *str2 in self)
    {
      if ([str1 compare:str2 options:NSCaseInsensitiveSearch] == NSOrderedSame)
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
