// -*- c-style: gnu -*-

#import "ActAppKitExtensions.h"

@implementation NSCell (ActAppKitExtensions)

// vCentered is private, but it's impossible to resist..

- (BOOL)isVerticallyCentered
{
  return _cFlags.vCentered;
}

- (void)setVerticallyCentered:(BOOL)flag
{
  _cFlags.vCentered = flag ? YES : NO;
}

@end


@implementation NSTableView (ActAppKitExtensions)

- (void)reloadDataForRow:(NSInteger)row
{
  NSIndexSet *rows = [NSIndexSet indexSetWithIndex:row];
  NSIndexSet *cols = [NSIndexSet indexSetWithIndexesInRange:
		      NSMakeRange(0, [[self tableColumns] count])];

  [self reloadDataForRowIndexes:rows columnIndexes:cols];
}

@end
