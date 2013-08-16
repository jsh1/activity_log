
#import "ActAppDelegate.h"

@implementation ActAppDelegate

static act::database *_database;

- (void)dealloc
{
    delete _database;
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
    _database = new act::database();
}

- (act::database *)database
{
    return _database;
}

@end
