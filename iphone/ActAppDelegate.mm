/* -*- c-style: gnu -*-

   Copyright (c) 2013 John Harper <jsh@unfactored.org>

   Permission is hereby granted, free of charge, to any person
   obtaining a copy of this software and associated documentation files
   (the "Software"), to deal in the Software without restriction,
   including without limitation the rights to use, copy, modify, merge,
   publish, distribute, sublicense, and/or sell copies of the Software,
   and to permit persons to whom the Software is furnished to do so,
   subject to the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE. */

#import "ActAppDelegate.h"

#import "ActActivitiesViewController.h"
#import "ActColor.h"
#import "ActDatabaseManager.h"
#import "ActDropboxParams.h"
#import "ActFileManager.h"
#import "ActQueryListViewController.h"

#import "act-config.h"

@implementation ActAppDelegate

@synthesize window = _window;
@synthesize navigationController = _navigationController;
@synthesize dropboxSession = _dropboxSession;
@synthesize remoteActivityPath = _remoteActivityPath;
@synthesize remoteGPSPath = _remoteGPSPath;

static const char *
defaults_getenv(const char *key)
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *str = [defaults stringForKey:[NSString stringWithUTF8String:key]];
  return str != nil ? [str UTF8String] : nullptr;
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)opts
{
  if (NSString *path = [[NSBundle mainBundle]
			pathForResource:@"defaults" ofType:@"plist"])
    {
      if (NSData *data = [NSData dataWithContentsOfFile:path])
	{
	  if (NSDictionary *dict
	      = [NSPropertyListSerialization propertyListWithData:data
		 options:NSPropertyListImmutable format:nil error:nil])
	    {
	      [[NSUserDefaults standardUserDefaults] registerDefaults:dict];
	    }
	}
    }

  /* Make act::config look in our user defaults for its ACT_ environment
     variables. */

  act::config::set_getenv(defaults_getenv);

  _remoteActivityPath = [@"/" stringByAppendingPathComponent:
			 [NSString stringWithUTF8String:
			  act::shared_config().activity_dir()]];
  _remoteGPSPath = [@"/" stringByAppendingPathComponent:
			[NSString stringWithUTF8String:
			 act::shared_config().gps_file_dir()]];

  [DBRequest setNetworkRequestDelegate:self];

  _dropboxSession = [[DBSession alloc] initWithAppKey:@DROPBOX_KEY
		     appSecret:@DROPBOX_SECRET root:kDBRootDropbox];

  [DBSession setSharedSession:_dropboxSession];

  [[NSBundle mainBundle] loadNibNamed:@"Main" owner:self options:nil];

  _window.tintColor = [ActColor redTextColor];

  ActQueryListViewController *controller
    = [ActQueryListViewController instantiate];

  controller.title = @"Activities";

  [_navigationController pushViewController:controller animated:NO];

  [controller pushAllActivitiesAnimated:NO];

  if (!self.dropboxLinked)
    [controller configAction:self];

  return YES;
}

- (BOOL)isDropboxLinked
{
  return [_dropboxSession isLinked];
}

- (void)setDropboxLinked:(BOOL)state
{
  BOOL linked = [_dropboxSession isLinked];

  if (state && !linked)
    {
      [_dropboxSession linkFromController:_navigationController];
    }
  else if (!state && linked)
    {
      [ActFileManager shutdownSharedManager];
      [_dropboxSession unlinkAll];
    }
}

- (NSString *)remoteActivityPath:(NSString *)rel_path
{
  /* Dropbox is case-insensitive and case-mutilating, so work in lower-case. */

  return [[_remoteActivityPath stringByAppendingPathComponent:rel_path]
	  lowercaseString];
}

- (NSString *)remoteGPSPath:(NSString *)rel_path
{
  return [[_remoteGPSPath stringByAppendingPathComponent:rel_path]
	  lowercaseString];
}

- (NSString *)temporaryLocalFile
{
  NSString *tmp_dir = NSTemporaryDirectory();
  NSFileManager *fm = [NSFileManager defaultManager];

  while (1)
    {
      NSString *path = [tmp_dir stringByAppendingPathComponent:
			[NSString stringWithFormat:@"%08x", arc4random()]];

      if (![fm fileExistsAtPath:path])
	return path;
    }

  /* not reached. */
}

- (BOOL)application:(UIApplication *)app handleOpenURL:(NSURL *)url
{
  if ([_dropboxSession handleOpenURL:url])
    {
      if ([_dropboxSession isLinked])
	{
	  /* This should make view controllers update. */

	  [[ActFileManager sharedManager] reset];
	}

      return YES;
    }

  return NO;
}

- (void)applicationWillResignActive:(UIApplication *)app
{
}

- (void)applicationDidEnterBackground:(UIApplication *)app
{
  [[ActDatabaseManager sharedManager] synchronize];
  [[ActFileManager sharedManager] synchronize];
}

- (void)applicationWillEnterForeground:(UIApplication *)app
{
  [[ActFileManager sharedManager] reset];
  [[ActDatabaseManager sharedManager] removeAllActivities];
}

- (void)applicationDidBecomeActive:(UIApplication *)app
{
}

- (void)applicationWillTerminate:(UIApplication *)app
{
  [ActDatabaseManager shutdownSharedManager];
  [ActFileManager shutdownSharedManager];
}

/* DBNetworkRequestDelegate methods. */

- (void)networkRequestStarted
{
  if (_dropboxRequests++ == 0)
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)networkRequestStopped
{
  if (--_dropboxRequests == 0)
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

@end
