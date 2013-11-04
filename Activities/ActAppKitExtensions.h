// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

@interface NSCell (ActAppKitExtensions)

@property(getter=isVerticallyCentered) BOOL verticallyCentered;
  
@end


@interface NSTableView (ActAppKitExtensions)

- (void)reloadDataForRow:(NSInteger)row;

@end
