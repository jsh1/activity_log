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

#import "ActDatabaseManager.h"

#import "ActAppDelegate.h"

#import "act-config.h"
#import "act-format.h"
#import "act-gps-activity.h"

#import "DropboxSDK.h"

#import "FoundationExtensions.h"

#define BODY_WRAP_COLUMN 72

NSString *const ActMetadataCacheDidChange = @"ActMetadataCacheDidChange";
NSString *const ActFileCacheDidChange = @"ActFileCacheDidChange";
NSString *const ActActivityDatabaseDidChange = @"ActActivityDatabaseDidChange";
NSString *const ActActivityDidChangeField = @"ActActivityDidChangeField";
NSString *const ActActivityDidChangeBody = @"ActActivityDidChangeBody";

#if DEBUG && !defined(VERBOSE)
# define VERBOSE 1
#endif

#define LOG(x) do {if (VERBOSE) NSLog x;} while (0)

@implementation ActDatabaseManager

static ActDatabaseManager *_sharedManager;

+ (ActDatabaseManager *)sharedManager
{
  if (_sharedManager == nil)
    {
      ActAppDelegate *delegate
        = (ActAppDelegate *)[UIApplication sharedApplication].delegate;

      if (!delegate.dropboxLinked)
	return nil;

      _sharedManager = [[self alloc] init];
    }

  return _sharedManager;
}

+ (void)shutdownSharedManager
{
  [_sharedManager invalidate];
  _sharedManager = nil;
}

- (id)init
{
  self = [super init];
  if (self == nil)
    return nil;

  ActAppDelegate *delegate
    = (ActAppDelegate *)[UIApplication sharedApplication].delegate;

  _dbClient = [[DBRestClient alloc] initWithSession:delegate.dropboxSession];
  if (_dbClient == nil)
    return nil;

  [_dbClient setDelegate:self];

  /* Can't just reload() the entire cached database directory, it may
     include files that no longer exist in the master store, we'll
     manually call add_activity() for every file. */

  _database.reset(new act::database());

  NSString *cache_dir
    = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
					   NSUserDomainMask, YES) firstObject];

  cache_dir = [cache_dir stringByAppendingPathComponent:@"ActDatabaseManager"];

  _localFilePath = [cache_dir stringByAppendingPathComponent:@"file-cache"];

  _remoteActivityPath = [@"/" stringByAppendingPathComponent:
			 [NSString stringWithUTF8String:
			  act::shared_config().activity_dir()]];
  _remoteGPSPath = [@"/" stringByAppendingPathComponent:
			[NSString stringWithUTF8String:
			 act::shared_config().gps_file_dir()]];

  _pendingMetadata = [NSMutableSet set];
  _metadataCache = [NSMutableDictionary dictionary];
  _metadataCachePath = [cache_dir stringByAppendingPathComponent:
			@"metadata-cache.json"];

  if (NSData *data = [NSData dataWithContentsOfFile:_metadataCachePath])
    {
      _oldMetadataCache = [[NSJSONSerialization JSONObjectWithData:data
			    options:0 error:nil] mutableCopy];
    }

  _fileCacheRevisionsPath = [cache_dir stringByAppendingPathComponent:
			     @"file-cache-revisions.json"];

  if (NSData *data = [NSData dataWithContentsOfFile:_fileCacheRevisionsPath])
    {
      _fileCacheRevisions = [[NSJSONSerialization JSONObjectWithData:data
			      options:0 error:nil] mutableCopy];
    }

  if (_fileCacheRevisions == nil)
    _fileCacheRevisions = [NSMutableDictionary dictionary];

  _pendingFileCacheRevisions = [NSMutableDictionary dictionary];

  _addedActivityRevisions = [NSMutableDictionary dictionary];

  return self;
}

- (void)invalidate
{
  [self synchronize];

  [_dbClient cancelAllRequests];
  [_dbClient setDelegate:nil];
  _dbClient = nil;
}

- (void)dealloc
{
  [self invalidate];
}

- (BOOL)needsSynchronize
{
  return _metadataCacheNeedsSynchronize || _fileCacheRevisionsNeedsSynchronize;
}

- (void)synchronize
{
  if (_metadataCacheNeedsSynchronize)
    {
      NSMutableDictionary *dict = [_metadataCache mutableCopy];
      if (_oldMetadataCache != nil)
	[dict addEntriesFromDictionary:_oldMetadataCache];

      NSData *data = [NSJSONSerialization dataWithJSONObject:dict
		      options:0 error:nil];

      if ([data writeToFile:_metadataCachePath atomically:YES])
	{
	  _metadataCacheNeedsSynchronize = NO;
	}
      else
	{
	  [[NSFileManager defaultManager]
	   removeItemAtPath:_metadataCachePath error:nil];
	}
    }

  if (_fileCacheRevisionsNeedsSynchronize)
    {
      NSData *data = [NSJSONSerialization dataWithJSONObject:
		      _fileCacheRevisions options:0 error:nil];

      if ([data writeToFile:_fileCacheRevisionsPath atomically:YES])
	{
	  _fileCacheRevisionsNeedsSynchronize = NO;
	}
      else
	{
	  [[NSFileManager defaultManager]
	   removeItemAtPath:_fileCacheRevisionsPath error:nil];
	}
    }
}

- (act::database *)database
{
  return _database.get();
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

- (NSDictionary *)metadataForRemotePath:(NSString *)path
{
  NSDictionary *dict = _metadataCache[path];

  BOOL need_load = dict == nil;

  if (dict == nil)
    dict = _oldMetadataCache[path];

  if (![dict isKindOfClass:[NSDictionary class]])
    dict = nil;

  if (need_load && ![_pendingMetadata containsObject:path])
    {
      NSString *hash = dict[@"hash"];

      [_dbClient loadMetadata:path withHash:hash];

      [_pendingMetadata addObject:path];

      LOG((@"loading %@ metadata.", path));
    }

  return dict;
}

- (void)reset
{
  if (_oldMetadataCache == nil)
    _oldMetadataCache = [NSMutableDictionary dictionary];

  [_oldMetadataCache addEntriesFromDictionary:_metadataCache];

  [_metadataCache removeAllObjects];

  BOOL db_empty = _database->items().size() == 0;

  _database->clear();

  [_addedActivityRevisions removeAllObjects];

  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActMetadataCacheDidChange object:self];

  if (!db_empty)
    {
      [[NSNotificationCenter defaultCenter]
       postNotificationName:ActActivityDatabaseDidChange object:self];
    }
}

static NSDictionary *
metadata_dictionary(DBMetadata *meta)
{
  if (meta.isDeleted || !meta.isDirectory)
    return nil;

  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  if (id hash = meta.hash)
    dict[@"hash"] = hash;

  if (id rev = meta.rev)
    dict[@"rev"] = rev;

  NSMutableArray *contents = [NSMutableArray array];

  for (DBMetadata *sub in meta.contents)
    {
      if (sub.isDeleted)
	continue;

      NSMutableDictionary *sub_dict = [NSMutableDictionary dictionary];

      sub_dict[@"name"] = [sub.path lastPathComponent];

      /* Note: not including hash field, we only use it to avoid
	 receiving directory metadata redundantly. */

      if (id rev = sub.rev)
	sub_dict[@"rev"] = rev;

      if (sub.isDirectory)
	sub_dict[@"directory"] = @YES;

      [contents addObject:sub_dict];
    }

  dict[@"contents"] = contents;

  return dict;
}

- (void)restClient:(DBRestClient *)client loadedMetadata:(DBMetadata *)meta
{
  NSString *path = [meta.path lowercaseString];

  [_pendingMetadata removeObject:path];

  if (NSDictionary *dict = metadata_dictionary(meta))
    {
      _metadataCache[path] = dict;
      [_oldMetadataCache removeObjectForKey:path];

      /* FIXME: remove cached sub-directories that no longer exist? */
    }
  else
    _metadataCache[path] = [NSNull null];

  _metadataCacheNeedsSynchronize = YES;

  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActMetadataCacheDidChange object:self
   userInfo:@{@"remotePath": path}];
}

- (void)restClient:(DBRestClient *)client
    metadataUnchangedAtPath:(NSString *)path
{
  path = [path lowercaseString];

  LOG((@"%@ metadata unchanged.", path));

  if (_metadataCache[path] == nil)
    {
      id obj = _oldMetadataCache[path];

      if (obj == nil)
	{
	  obj = [NSNull null];
	  _metadataCacheNeedsSynchronize = YES;
	}

      _metadataCache[path] = obj;
      [_oldMetadataCache removeObjectForKey:path];
    }

  [_pendingMetadata removeObject:path];
}

- (void)restClient:(DBRestClient *)client
    loadMetadataFailedWithError:(NSError *)err
{
  LOG((@"ERROR: metadata %@.", [[err userInfo] objectForKey:@"path"]));
}

- (NSString *)localPathForRemotePath:(NSString *)path revision:(NSString *)rev
{
  NSString *dest_path = [_localFilePath stringByAppendingPathComponent:path];

  NSFileManager *fm = [NSFileManager defaultManager];

  if ([fm fileExistsAtPath:dest_path] && rev != nil
      && [_fileCacheRevisions[path] isEqualToString:rev])
    {
      /* File is already cached and up to date, return it's local path */

      return dest_path;
    }
  else if (_pendingFileCacheRevisions[path] == nil)
    {
      /* File needs to be brought into our cache. */

      [fm removeItemAtPath:dest_path error:nil];
      [fm createDirectoryAtPath:[dest_path stringByDeletingLastPathComponent]
       withIntermediateDirectories:YES attributes:nil error:nil];

      [_dbClient loadFile:path atRev:rev intoPath:dest_path];

      _pendingFileCacheRevisions[path] = rev;

      LOG((@"loading file %@.", path));
    }

  return nil;
}

- (void)loadActivityFromPath:(NSString *)rel_path revision:(NSString *)rev
{
  NSString *path = [self remoteActivityPath:rel_path];

  NSString *dest_path = [self localPathForRemotePath:path revision:rev];

  if (dest_path != nil)
    {
      /* File is already cached and up to date. Add it to database
	 if not already done so. */

      NSString *added_rev = _addedActivityRevisions[path];

      if (![added_rev isEqualToString:rev])
	{
	  _addedActivityRevisions[path] = rev;

	  if (_database->add_activity([dest_path UTF8String]))
	    {
	      [[NSNotificationCenter defaultCenter]
	       postNotificationName:ActActivityDatabaseDidChange object:self];
	    }
	}
    }
  else
    {
      /* File is being loaded asynchronously. */

      [_addedActivityRevisions removeObjectForKey:path];
    }
}

- (void)restClient:(DBRestClient *)client loadedFile:(NSString *)destPath
{
  /* FIXME: ugly way to go back to the remote path..  */

  NSString *path = [@"/" stringByAppendingPathComponent:
		    [destPath stringByRemovingPathPrefix:_localFilePath]];

  LOG((@"loaded file %@.", path));

  NSString *rev = _pendingFileCacheRevisions[path];

  if (rev != nil)
    {
      [_pendingFileCacheRevisions removeObjectForKey:path];

      _fileCacheRevisions[path] = rev;
      _fileCacheRevisionsNeedsSynchronize = YES;

      [[NSNotificationCenter defaultCenter]
       postNotificationName:ActFileCacheDidChange object:self
       userInfo:@{@"remotePath": path, @"localPath": destPath}];
    }
  else
    LOG((@"ERROR: unexpected file %@.", path));
}

- (void)restClient:(DBRestClient *)client
    loadFileFailedWithError:(NSError *)err
{
  NSString *path = [[[err userInfo] objectForKey:@"path"] lowercaseString];

  [_pendingFileCacheRevisions removeObjectForKey:path];

  LOG((@"ERROR: file %@.", [[err userInfo] objectForKey:@"path"]));
}

- (void)activity:(const act::activity_storage_ref)a
    didChangeField:(NSString *)name;
{
//  [self setNeedsSynchronize:YES];

  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActActivityDidChangeField object:self
   userInfo:@{@"activity": [NSValue valueWithPointer:&a], @"field": name}];
}

- (void)activityDidChangeBody:(const act::activity_storage_ref)a
{
//  [self setNeedsSynchronize:YES];

  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActActivityDidChangeBody object:self
   userInfo:@{@"activity": [NSValue valueWithPointer:&a]}];
}

@end

@implementation ActDatabaseManager (ActivityFields)

- (NSString *)stringForField:(NSString *)name
    ofActivity:(const act::activity &)a
{
  const char *field = [name UTF8String];
  act::field_id field_id = act::lookup_field_id(field);
  act::field_data_type field_type = act::lookup_field_data_type(field_id);

  std::string ret;

  switch (field_type)
    {
    case act::field_data_type::string:
      if (const std::string *s = a.field_ptr(field))
	return [NSString stringWithUTF8String:s->c_str()];
      break;

    case act::field_data_type::keywords:
      if (const std::vector<std::string>
	  *keys = a.field_keywords_ptr(field_id))
	{
	  act::format_keywords(ret, *keys);
	}
      break;

    default:
      if (double value = a.field_value(field_id))
	{
	  act::unit_type unit = a.field_unit(field_id);
	  act::format_value(ret, field_type, value, unit);
	}
      break;
    }

  return [NSString stringWithUTF8String:ret.c_str()];
}

- (BOOL)isFieldReadOnly:(NSString *)name ofActivity:(const act::activity &)a
{
  return a.storage()->field_read_only_p([name UTF8String]);
}

- (void)setString:(NSString *)str forField:(NSString *)name
    ofActivity:(act::activity &)a
{
  const char *field_name = [name UTF8String];
  auto id = act::lookup_field_id(field_name);
  if (id != act::field_id::custom)
    field_name = act::canonical_field_name(id);

  // FIXME: trim whitespace?

  if ([str length] != 0)
    {
      auto type = act::lookup_field_data_type(id);

      std::string value([str UTF8String]);
      act::canonicalize_field_string(type, value);

      (*a.storage())[field_name] = value;
      a.storage()->increment_seed();
    }
  else
    a.storage()->delete_field(field_name);

  [self activity:a.storage() didChangeField:name];
}

- (void)deleteField:(NSString *)name ofActivity:(act::activity &)a
{
  [self setString:nil forField:name ofActivity:a];
}

- (void)renameField:(NSString *)oldName to:(NSString *)newName
    ofActivity:(act::activity &)a
{
  if ([newName length] == 0)
    return [self deleteField:newName ofActivity:a];

  a.storage()->set_field_name([oldName UTF8String], [newName UTF8String]);

  [self activity:a.storage() didChangeField:oldName];
  [self activity:a.storage() didChangeField:newName];
}

- (NSString *)bodyStringOfActivity:(const act::activity &)a
{
  const std::string &s = a.body();

  if (s.size() != 0)
    {
      NSMutableString *str = [NSMutableString string];

      const char *ptr = s.c_str();

      while (const char *eol = strchr(ptr, '\n'))
	{
	  NSString *tem = [[NSString alloc] initWithBytes:ptr
			   length:eol-ptr encoding:NSUTF8StringEncoding];
	  [str appendString:tem];
#if !__has_feature(objc_arc)
	  [tem release];
#endif
	  ptr = eol + 1;
	  if (eol[1] == '\n')
	    [str appendString:@"\n\n"], ptr++;
	  else if (eol[1] != 0)
	    [str appendString:@" "];
	}

      if (*ptr != 0)
	[str appendString:[NSString stringWithUTF8String:ptr]];

      return str;
    }

  return @"";
}

- (void)setBodyString:(NSString *)str ofActivity:(act::activity &)a
{
  static const char whitespace[] = " \t\n\f\r";

  const char *ptr = [str UTF8String];
  ptr = ptr + strspn(ptr, whitespace);

  std::string wrapped;
  size_t column = 0;

  while (*ptr != 0)
    {
      const char *word = ptr + strcspn(ptr, whitespace);

      if (word > ptr)
	{
	  if (column + (word - ptr) >= BODY_WRAP_COLUMN)
	    {
	      wrapped.push_back('\n');
	      column = 0;
	    }
	  else if (column > 0)
	    {
	      wrapped.push_back(' ');
	      column++;
	    }

	  wrapped.append(ptr, word - ptr);
	  column += word - ptr;
	  ptr = word;
	}

      int newlines = 0;

    again:
      switch (*ptr)
	{
	case ' ':
	case '\t':
	case '\f':
	case '\r':
	  ptr++;
	  goto again;
	case '\n':
	  newlines++;
	  ptr++;
	  goto again;
	default:
	  break;
	}

      while (newlines-- > 1)
	{
	  wrapped.push_back('\n');
	  column = BODY_WRAP_COLUMN;
	}
    }

  if (column > 0)
    wrapped.push_back('\n');

  if (wrapped != a.storage()->body())
    {
      // FIXME: undo management

      std::swap(a.storage()->body(), wrapped);
      a.storage()->increment_seed();

      [self activityDidChangeBody:a.storage()];
    }
}

@end
