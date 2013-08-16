
#import <AppKit/AppKit.h>

#import "act-database.h"

@interface ActAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property(readonly) act::database *database;

@end
