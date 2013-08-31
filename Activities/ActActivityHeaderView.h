// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

@interface ActActivityHeaderView : ActActivitySubview
{
  NSMutableArray *_displayedFields;
}

@property(nonatomic, copy) NSArray *displayedFields;

- (BOOL)displaysField:(NSString *)name;
- (void)addDisplayedField:(NSString *)name;
- (void)removeDisplayedField:(NSString *)name;

@end
