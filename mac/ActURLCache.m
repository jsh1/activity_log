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

#import "ActURLCache.h"

#import <sqlite3.h>

@interface ActURLCache (internal)
- (void)commitCachedURL:(ActCachedURL *)url;
@end

@interface ActCachedURL (internal)
- (void)setCache:(ActURLCache *)cache;
- (void)setData:(NSData *)data;
- (void)setError:(NSError *)err;
- (NSURLSessionTask *)task;
- (void)setTask:(NSURLSessionTask *)task;
- (int)fileId;
- (void)setFileId:(int)x;
- (void)dispatch;
@end

#define MAX_SIZE (64*1024*1024)
#define EXPIRES (365*24*60*60)

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

- (NSString *)_pathForFileId:(int)x
{
  return [_path stringByAppendingPathComponent:
	  [NSString stringWithFormat:@"%08x.dat", (unsigned int)x]];
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

  if (fileid != 0)
    {
      [url setFileId:fileid];

      if (time(NULL) < (time_t)expires)
	{
	  [url setData:[NSData dataWithContentsOfFile:
			[self _pathForFileId:fileid]]];

	  if ([[url data] length] != 0)
	    {
	      [url dispatch];
	      return YES;
	    }
	}
    }

  NSURLRequest *request = [NSURLRequest requestWithURL:[url URL]];

  NSURLSessionTask *task = [[NSURLSession sharedSession]
    dataTaskWithRequest:request completionHandler:^
    (NSData *data, NSURLResponse *response, NSError *err)
      {
	[url setTask:nil];
	if (err == nil)
	  {
	    [url setData:data];
	    [self commitCachedURL:url];
	  }
	else
	  [url setError:err];
	[url dispatch];
      }];

  [url setTask:task];
  [task resume];

  return YES;
}

- (void)commitCachedURL:(ActCachedURL *)url
{            
  NSData *data = [url data];
  const char *url_str = [[[url URL] absoluteString] UTF8String];
  NSFileManager *fm = [NSFileManager defaultManager];

  if ([url fileId] != 0)
    {
      int fileid = [url fileId];

      [fm removeItemAtPath:[self _pathForFileId:fileid] error:NULL];

      if (_deleteStmt == NULL)
	{
	  TRY(sqlite3_prepare_v2(_handle, "DELETE FROM cache WHERE fileid = ?",
				 -1, (sqlite3_stmt **)&_deleteStmt, NULL));
	}

      TRY(sqlite3_bind_int(_deleteStmt, 1, fileid));
      assert(sqlite3_step(_deleteStmt) == SQLITE_DONE);
      TRY(sqlite3_reset(_deleteStmt));
    }

  if (data != nil)
    {
      int fileid = 0;
      NSString *path = nil;

      while (1)
	{
	  fileid = (int)arc4random();
	  path = [self _pathForFileId:fileid];
	  if (![fm fileExistsAtPath:path])
	    break;
	}

      int expires = time(NULL) + EXPIRES;	// FIXME: honour http headers?

      if (_insertStmt == NULL)
	{
	  TRY(sqlite3_prepare_v2(_handle, "INSERT INTO cache"
				 " VALUES(?, ?, ?, ?)", -1,
				 (sqlite3_stmt **) &_insertStmt, NULL));
	}

      TRY(sqlite3_bind_text(_insertStmt, 1, url_str, -1, SQLITE_TRANSIENT));
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
}

- (void)pruneCaches
{
  NSFileManager *fm = [NSFileManager defaultManager];

  sqlite3_stmt *stmt = NULL;

  TRY(sqlite3_prepare_v2(_handle, "SELECT fileid, expires, size"
			 " FROM cache ORDER BY expires", -1, &stmt, NULL));

  size_t total_size = 0;
  int min_expires = INT_MAX;
  
  while (sqlite3_step(stmt) == SQLITE_ROW)
    {
      total_size += sqlite3_column_int(stmt, 2);

      if (total_size > MAX_SIZE)
	{
	  int fileid = sqlite3_column_int(stmt, 0);
	  int expires = sqlite3_column_int(stmt, 1);

	  [fm removeItemAtPath:[self _pathForFileId:fileid] error:NULL];

	  if (min_expires > expires)
	    min_expires = expires;
	}
    }

  sqlite3_finalize(stmt);

  if (min_expires < INT_MAX)
    {
      TRY(sqlite3_prepare_v2(_handle, "DELETE FROM cache WHERE expires <= ?",
			     -1, &stmt, NULL));
      TRY(sqlite3_bind_int(stmt, 1, min_expires));

      assert(sqlite3_step(stmt) == SQLITE_DONE);
      sqlite3_finalize(stmt);
    }
}

- (void)emptyCaches
{
  NSFileManager *fm = [NSFileManager defaultManager];

  sqlite3_stmt *stmt = NULL;
  TRY(sqlite3_prepare_v2(_handle, "SELECT fileid FROM cache",
			 -1, &stmt, NULL));

  while (sqlite3_step(stmt) == SQLITE_ROW)
    {
      int fileid = sqlite3_column_int(_queryStmt, 0);
      [fm removeItemAtPath:[self _pathForFileId:fileid] error:NULL];
    }

  sqlite3_finalize(stmt);

  TRY(sqlite3_exec(_handle, "DELETE FROM cache", NULL, NULL, NULL));
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
  [_task release];
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

  [_task cancel];
}

- (void)_sendReply:(id)arg
{
  [_delegate cachedURLDidFinish:self];
  _dispatching = NO;
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

- (NSURLSessionTask *)task
{
  return _task;
}

- (void)setTask:(NSURLSessionTask *)task
{
  [_task release];
  _task = [task retain];
}

- (int)fileId
{
  return _fileId;
}

- (void)setFileId:(int)x
{
  _fileId = x;
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
