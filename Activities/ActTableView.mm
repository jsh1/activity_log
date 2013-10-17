// -*- c-style: gnu -*-

#import "ActTableView.h"

#import "ActColor.h"

@implementation ActTableView

- (id)_alternatingRowBackgroundColors
{
  return [ActColor controlAlternatingRowBackgroundColors];
}

@end
