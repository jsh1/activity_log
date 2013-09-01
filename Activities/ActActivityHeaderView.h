// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

@interface ActActivityHeaderView : ActActivitySubview

@property(nonatomic, copy) NSArray *displayedFields;

- (BOOL)displaysField:(NSString *)name;
- (void)addDisplayedField:(NSString *)name;
- (void)removeDisplayedField:(NSString *)name;

@end
