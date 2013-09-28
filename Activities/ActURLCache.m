// -*- c-style: gnu -*-

#import "ActURLCache.h"

#import <sqlite3.h>

@interface ActCachedURL (internal) <NSURLConnectionDataDelegate>
- (void)setCache:(ActURLCache *)cache;
- (void)setData:(NSData *)data;
- (void)setError:(NSError *)err;
- (NSURLConnection *)connection;
- (void)setConnection:(NSURLConnection *)conn;
- (void)dispatch;
@end

#define TRY(x)								\
  do {									\
    int err = x;							\
    if (x != SQLITE_OK)							\
      {									\
	NSLog(@"SQLite error: %d: %s", err, sqlite3_errmsg(_handle));	\
	abort();							\
      }									\
  } while(0)

@implementation ActURLCache

static ActURLCache *_sharedCache;

+ (ActURLCache *)sharedURLCache
{
  NSString *path;

  if (_sharedCache == nil)
    {
      path = [[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
						    NSUserDomainMask,
						    YES) lastObject]
	       stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]]
	      stringByAppendingPathComponent:@"ActURLCache"];
      if (path == nil)
	return nil;

      _sharedCache = [[self alloc] initWithPath:path];
    }

  return _sharedCache;
}

- (id)initWithPath:(NSString *)path
{
  NSFileManager *fm;
  BOOL isdir;
  NSString *file;

  self = [super init];
  if (self == nil)
    return nil;

  _path = [path copy];

  fm = [NSFileManager defaultManager];

  if (![fm fileExistsAtPath:_path isDirectory:&isdir])
    {
      if (![fm createDirectoryAtPath:_path withIntermediateDirectories:YES
	    attributes:nil error:nil])
	{
	  [self release];
	  return nil;
	}
    }
  else if (!isdir)
    {
      [self release];
      return nil;
    }

  file = [_path stringByAppendingPathComponent:@"cache.db"];
  TRY(sqlite3_open_v2([file UTF8String], (sqlite3**)&_handle,
		      SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL));

  if (_handle == NULL)
    {
      [self release];
      return nil;
    }

  TRY(sqlite3_exec(_handle, "CREATE TABLE IF NOT EXISTS cache "
		   "(url TEXT PRIMARY KEY, fileid INTEGER,"
		   " expires INTEGER, size INTEGER)", NULL, NULL, NULL));

  return self;
}

- (void)dealloc
{
  [_path release];

  TRY(sqlite3_close(_handle));

  [super dealloc];
}

- (BOOL)loadURL:(ActCachedURL *)url
{
  assert([url URL] != nil && [url delegate] != nil);
  assert([url cache] == nil);

  if (_queryStmt == NULL)
    {
      TRY(sqlite3_prepare_v2(_handle, "SELECT fileid, expires"
			     " FROM cache WHERE url = ?", -1,
			     (sqlite3_stmt **) &_queryStmt, NULL));
      if (_queryStmt == NULL)
	return NO;
    }

  [url setCache:self];

  int fileid = 0, expires = 0;

  TRY(sqlite3_bind_text(_queryStmt, 1, [[[url URL] absoluteString] UTF8String],
			-1, SQLITE_TRANSIENT));

  if (sqlite3_step(_queryStmt) == SQLITE_ROW)
    {
      fileid = sqlite3_column_int(_queryStmt, 0);
      expires = sqlite3_column_int(_queryStmt, 1);
    }

  TRY(sqlite3_reset(_queryStmt));
  TRY(sqlite3_clear_bindings(_queryStmt));

  if (fileid != 0 && time(NULL) < (time_t)expires)
    {
      NSString *file = [_path stringByAppendingPathComponent:
			[NSString stringWithFormat:@"%08x.dat",
			 (unsigned int)fileid]];
      [url setData:[NSData dataWithContentsOfFile:file]];

      if ([[url data] length] != 0)
	{
	  [url dispatch];
	  return YES;
	}
    }

  NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[url URL]];
  NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request
			   delegate:url startImmediately:NO];
  [request release];
  [url setConnection:conn];
  [conn scheduleInRunLoop:[NSRunLoop mainRunLoop]
   forMode:NSRunLoopCommonModes];
  [conn start];
  [conn release];

  return YES;
}

- (void)insertData:(NSData *)data forURL:(NSURL *)url
{            
  NSFileManager *fm = [NSFileManager defaultManager];

  int fileid = 0;
  NSString *path = nil;
  while (1)
    {
      fileid = (int)arc4random();
      path = [_path stringByAppendingPathComponent:
	      [NSString stringWithFormat:@"%08x.dat", (unsigned int)fileid]];
      if (![fm fileExistsAtPath:path])
	break;
    }

  int expires = time(NULL) + 7*24*60*60;	// FIXME: honour http headers?

  if (_insertStmt == NULL)
    {
      TRY(sqlite3_prepare_v2(_handle, "INSERT INTO cache VALUES(?, ?, ?, ?)",
			     -1, (sqlite3_stmt **) &_insertStmt, NULL));
      if (_insertStmt == NULL)
	return;
    }

  TRY(sqlite3_bind_text(_insertStmt, 1, [[url absoluteString] UTF8String],
			-1, SQLITE_TRANSIENT));
  TRY(sqlite3_bind_int(_insertStmt, 2, fileid));
  TRY(sqlite3_bind_int(_insertStmt, 3, expires));
  TRY(sqlite3_bind_int(_insertStmt, 4, (int) [data length]));

  if (sqlite3_step(_insertStmt) == SQLITE_DONE)
    {
      [data writeToFile:path atomically:NO];
    }

  TRY(sqlite3_reset(_insertStmt));
  TRY(sqlite3_clear_bindings(_insertStmt));
}

- (void)purgeCaches
{
  // FIXME: implement this
}

@end

@implementation ActCachedURL

@synthesize URL = _url;
@synthesize delegate = _delegate;
@synthesize userInfo = _userInfo;

@synthesize cache = _cache;
@synthesize data = _data;
@synthesize error = _error;

- (void)dealloc
{
  [_url release];
  [_userInfo release];
  [_cache release];
  [_connection release];
  [_data release];
  [super dealloc];
}

- (void)cancel
{
  if (_dispatching)
    {
      _dispatching = NO;
      [[NSRunLoop mainRunLoop] cancelPerformSelector:@selector(_sendReply:)
       target:self argument:nil];
    }

  [_connection cancel];
}

- (void)_sendReply:(id)arg
{
  [_delegate cachedURLDidFinish:self];
  _dispatching = NO;
}

// NSURLConnectionDataDelegate methods

- (void)connection:(NSURLConnection *)conn
    didReceiveResponse:(NSURLResponse *)response
{
  [_data setLength:0];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)conn
    willCacheResponse:(NSCachedURLResponse *)response
{
  return nil;
}

- (void)connection:(NSURLConnection *)conn didFailWithError:(NSError *)error
{
  [_error release];
  _error = [error copy];

  [_data release];
  _data = nil;

  [_connection release];
  _connection = nil;

  [self dispatch];
}

- (void)connection:(NSURLConnection *)conn didReceiveData:(NSData *)data
{
  if (_data == nil)
    _data = [[NSMutableData alloc] init];

  [_data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)conn
{
  [_connection release];
  _connection = nil;

  [_cache insertData:_data forURL:_url];

  [self dispatch];
}

@end

@implementation ActCachedURL (internal)

- (void)setCache:(ActURLCache *)cache
{
  [_cache release];
  _cache = [cache retain];
}

- (void)setData:(NSData *)data
{
  [_data release];
  _data = [data copy];
}

- (void)setError:(NSError *)err
{
  [_error release];
  _error = [err retain];
}

- (NSURLConnection *)connection
{
  return _connection;
}

- (void)setConnection:(NSURLConnection *)conn
{
  [_connection release];
  _connection = [conn retain];
}

- (void)dispatch
{
  if (!_dispatching)
    {
      _dispatching = YES;
      [[NSRunLoop mainRunLoop]
       performSelector:@selector(_sendReply:) target:self argument:nil
       order:0 modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
    }
}

@end
