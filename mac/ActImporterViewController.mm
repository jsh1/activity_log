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

#import "ActImporterViewController.h"

#import "ActAppDelegate.h"
#import "ActDevice.h"
#import "ActWindowController.h"

#import "act-config.h"
#import "act-format.h"
#import "act-gps-activity.h"
#import "act-new.h"

#import "AppKitExtensions.h"

@interface ActImporterActivity : NSObject
{
@public
  ActImporterViewController *_controller;
  NSURL *_url;
  BOOL _checked;
  BOOL _exists;
  BOOL _queued;
  std::unique_ptr<act::gps::activity> _data;
}

- (id)initWithURL:(NSURL *)url
    controller:(ActImporterViewController *)controller;

- (void)invalidate;

@property(nonatomic, readonly) NSURL *URL;
@property(nonatomic, getter=isChecked) BOOL checked;
@property(nonatomic) BOOL exists;
@property(nonatomic, readonly) const act::gps::activity *data;

@end

@implementation ActImporterViewController

+ (NSString *)viewNibName
{
  return @"ActImporterView";
}

- (id)initWithController:(ActWindowController *)controller
    options:(NSDictionary *)opts
{
  self = [super initWithController:controller options:opts];
  if (self == nil)
    return nil;

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedDeviceDidChange:)
   name:ActSelectedDeviceDidChange object:_controller];

  [self selectedDeviceDidChange:nil];

  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  for (NSTableColumn *col in [_tableView tableColumns])
    [[col dataCell] setVerticallyCentered:YES];
}

- (void)dealloc
{
  for (ActImporterActivity *obj in _activities)
    [obj invalidate];

  [_activities release];

  [super dealloc];
}

- (void)reloadDataForActivity:(ActImporterActivity *)item
{
  NSInteger row = [_activities indexOfObjectIdenticalTo:item];

  if (row != NSNotFound)
    [_tableView reloadDataForRow:row];
}

- (void)selectedDeviceDidChange:(NSNotification *)note
{
  for (ActImporterActivity *obj in _activities)
    [obj invalidate];

  [_activities release];

  _activities = [[NSMutableArray alloc] init];

  for (NSURL *url in [[[_controller selectedDevice]
		       activityURLs] reverseObjectEnumerator])
    {
      ActImporterActivity *obj
        = [[ActImporterActivity alloc] initWithURL:url controller:self];
      [_activities addObject:obj];
      [obj release];
    }

  [_tableView reloadData];
}

// gps_path is source file on entry, and will be new location if the
// file was able to be copied.

static void
copyFileToGPSDirectory(std::string &gps_path)
{
  if (const char *dir = act::shared_config().gps_file_dir())
    {
      time_t now = time(nullptr);
      struct tm tm = {0};
      localtime_r(&now, &tm);

      // FIXME: make the directory layout configurable?

      char buf[128];
      strftime(buf, sizeof(buf), "/%Y/", &tm);

      std::string dst_path(dir);
      dst_path.append(buf);

      if (const char *ptr = strrchr(gps_path.c_str(), '/'))
	{
	  dst_path.append(ptr);

	  NSFileManager *fm = [NSFileManager defaultManager];

	  NSString *src = [NSString stringWithUTF8String:gps_path.c_str()];
	  NSString *dst = [NSString stringWithUTF8String:dst_path.c_str()];

	  if ([fm copyItemAtPath:src toPath:dst error:nil])
	    {
	      using std::swap;
	      swap(gps_path, dst_path);
	    }
	}
    }
}

- (IBAction)importAction:(id)sender
{
  for (ActImporterActivity *item in _activities)
    {
      if ([item isChecked])
	{
	  const char *path = [[[item URL] path] UTF8String];

	  std::string gps_path(path);

	  if (!act::shared_config().find_gps_file(gps_path))
	    {
	      // try to copy file to gps directory

	      copyFileToGPSDirectory(gps_path);
	    }

	  act::arguments args("act-new");
	  args.push_back("--gps-file");
	  args.push_back(gps_path);

	  act::act_new(args);

	  [item setChecked:NO];
	  [item setExists:YES];
	}
    }

  [_controller performSelector:@selector(reloadActivities)
   withObject:nil afterDelay:.25];

  // FIXME: switch to viewing the earliest activity?

  [_tableView reloadData];
}

- (IBAction)revealAction:(id)sender
{
  ActImporterActivity *item
    = [_activities objectAtIndex:[_tableView selectedRow]];

  const char *path = [[[[item URL] path] lastPathComponent] UTF8String];
  act::database::query_term_ref term
    (new act::database::equal_term("gps-file", path));

  act::database::query q;
  q.set_term(term);

  [_controller showQueryResults:q];
  [_controller setWindowMode:ActWindowMode_Viewer];
}

// NSTableDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
  return [_activities count];
}

- (id)tableView:(NSTableView *)tv
  objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
  NSString *ident = [col identifier];
  ActImporterActivity *item = [_activities objectAtIndex:row];

  if ([ident isEqualToString:@"checked"])
    return [NSNumber numberWithBool:[item isChecked]];
  else if ([ident isEqualToString:@"reveal"])
    return nil;

  const act::gps::activity *a = [item data];
  if (a == nullptr)
    return nil;

  if ([ident isEqualToString:@"date"])
    {
      static NSDateFormatter *formatter;

      if (formatter == nil)
	{
	  NSLocale *locale
	    = [(ActAppDelegate *)[NSApp delegate] currentLocale];
	  formatter = [[NSDateFormatter alloc] init];
	  [formatter setLocale:locale];
	  [formatter setDateFormat:
	   [NSDateFormatter dateFormatFromTemplate:@"d/M/yy ha"
	    options:0 locale:locale]];
	}

      return [formatter stringFromDate:
	      [NSDate dateWithTimeIntervalSince1970:(time_t)a->start_time()]];
    }
  else if ([ident isEqualToString:@"distance"])
    {
      std::string buf;
      act::format_distance(buf, a->total_distance(), act::unit_type::unknown);
      return [NSString stringWithUTF8String:buf.c_str()];
    }
  else if ([ident isEqualToString:@"duration"])
    {
      std::string buf;
      act::format_duration(buf, a->total_duration());
      return [NSString stringWithUTF8String:buf.c_str()];
    }

  return nil;
}

// NSTableDelegate methods

- (void)tableView:(NSTableView *)tv willDisplayCell:(id)cell
    forTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
  NSString *ident = [col identifier];
  ActImporterActivity *item = [_activities objectAtIndex:row];

  if (([ident isEqualToString:@"checked"] && [item exists])
      || ([ident isEqualToString:@"reveal"] && ![item exists]))
    [cell setEnabled:NO];
  else
    [cell setEnabled:YES];
}

@end


@implementation ActImporterActivity

@synthesize URL = _url;
@synthesize checked = _checked;
@synthesize exists = _exists;

- (id)initWithURL:(NSURL *)url
    controller:(ActImporterViewController *)controller
{
  self = [super init];
  if (self == nil)
    return nil;

  _controller = controller;
  _url = [url copy];

  // FIXME: quicker to do all queries at once?

  const char *path = [[[url path] lastPathComponent] UTF8String];
  act::database::query_term_ref term
    (new act::database::equal_term("gps-file", path));

  act::database::query q;
  q.set_term(term);

  std::vector<act::database::item> results;
  [[_controller controller] database]->execute_query(q, results);

  _exists = results.size() != 0;
  _checked = !_exists;

  return self;
}

- (void)invalidate
{
  _controller = nil;
}

- (void)dealloc
{
  assert(_controller == nil);

  [_url release];
  [super dealloc];
}

- (const act::gps::activity *)data
{
  if (!_data && !_queued)
    {
      dispatch_queue_t q
	= dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

      dispatch_async(q, ^{
	act::gps::activity *a = new act::gps::activity;

	if (a->read_file([[_url path] UTF8String]))
	  {
	    _data.reset(a);

	    dispatch_async(dispatch_get_main_queue(), ^{
	      [_controller reloadDataForActivity:self];
	    });
	  }
	else
	  delete a;
      });

      _queued = YES;
    }

  return _data.get();
}

@end
