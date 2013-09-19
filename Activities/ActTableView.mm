// -*- c-style: gnu -*-

#import "ActTableView.h"

@implementation ActTableView

- (id)_alternatingRowBackgroundColors
{
  return @[[NSColor colorWithDeviceWhite:1 alpha:1],
	   [NSColor colorWithDeviceWhite:.95 alpha:1]];
}

@end
