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

#import "DropboxSDK.h"

#import "FoundationExtensions.h"

#define BODY_WRAP_COLUMN 72

NSString *const ActActivityDatabaseDidChange = @"ActActivityDatabaseDidChange";
NSString *const ActMetadataDatabaseDidChange = @"ActMetadataDatabaseDidChange";
NSString *const ActActivityListDidChange = @"ActActivityListDidChange";
NSString *const ActSelectedActivityDidChange = @"ActSelectedActivityDidChange";
NSString *const ActActivityDidChangeField = @"ActActivityDidChangeField";
NSString *const ActActivityDidChangeBody = @"ActActivityDidChangeBody";

@interface ActDatabaseManager ()
- (void)selectedActivityDidChange;
@end

@implementation ActDatabaseManager

static ActDatabaseManager *_sharedManager;

+ (ActDatabaseManager *)sharedManager
{
  if (_sharedManager == nil)
    {
      ActAppDelegate *delegate
        = (ActAppDelegate *)[[UIApplication sharedApplication] delegate];

      if (![delegate isDropboxLinked])
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
    = (ActAppDelegate *)[[UIApplication sharedApplication] delegate];

  _dbClient = [[DBRestClient alloc] initWithSession:[delegate dropboxSession]];
  if (_dbClient == nil)
    return nil;

  [_dbClient setDelegate:self];

  NSString *cache_dir
    = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
					   NSUserDomainMask, YES) firstObject];

  _localActivityPath
    = [cache_dir stringByAppendingPathComponent:@"activities"];

  NSString *act_dir = [NSString stringWithUTF8String:
		       act::shared_config().activity_dir()];

  _remoteActivityPath = [@"/" stringByAppendingPathComponent:act_dir];

  _database.reset(new act::database());

  /* Can't just reload() the entire cached database directory, it may
     include files that no longer exist in the master store, we'll
     manually call add_activity() for every file. */

  _pendingMetadata = [NSMutableSet set];

  _metadataCachePath = [cache_dir stringByAppendingPathComponent:
			@"metadata-cache.json"];

  _metadataCache = [NSMutableDictionary dictionary];

  if (NSData *data = [NSData dataWithContentsOfFile:_metadataCachePath])
    {
      _oldMetadataCache = [[NSJSONSerialization JSONObjectWithData:data
			    options:0 error:nil] mutableCopy];
    }

  _activityRevisionsPath = [cache_dir stringByAppendingPathComponent:
			    @"activity-revisions.json"];

  if (NSData *data = [NSData dataWithContentsOfFile:_activityRevisionsPath])
    {
      _activityRevisions = [[NSJSONSerialization JSONObjectWithData:data
			     options:0 error:nil] mutableCopy];
    }

  if (_activityRevisions == nil)
    _activityRevisions = [NSMutableDictionary dictionary];

  _pendingActivityRevisions = [NSMutableDictionary dictionary];
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
  return _metadataCacheNeedsSynchronize || _activityRevisionsNeedsSynchronize;
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

  if (_activityRevisionsNeedsSynchronize)
    {
      NSData *data = [NSJSONSerialization dataWithJSONObject:
		      _activityRevisions options:0 error:nil];

      if ([data writeToFile:_activityRevisionsPath atomically:YES])
	{
	  _activityRevisionsNeedsSynchronize = NO;
	}
      else
	{
	  [[NSFileManager defaultManager]
	   removeItemAtPath:_activityRevisionsPath error:nil];
	}
    }
}

- (act::database *)database
{
  return _database.get();
}

- (NSDictionary *)metadataForRemotePath:(NSString *)path
{
  /* Dropbox is case-insensitive and case-mutilating. */
  path = [path lowercaseString];

  NSDictionary *dict = [_metadataCache objectForKey:path];

  BOOL need_load = dict == nil;

  if (dict == nil)
    dict = [_oldMetadataCache objectForKey:path];

  if (![dict isKindOfClass:[NSDictionary class]])
    dict = nil;

  if (need_load && ![_pendingMetadata containsObject:path])
    {
      NSString *hash = [dict objectForKey:@"hash"];

      [_dbClient loadMetadata:path withHash:hash];

      [_pendingMetadata addObject:path];

      NSLog(@"loading metadata for %@ (hash = %@)", path, hash);
    }

  return dict;
}

- (NSDictionary *)activityMetadataForPath:(NSString *)path
{
  return [self metadataForRemotePath:
	  [_remoteActivityPath stringByAppendingPathComponent:path]];
}

- (BOOL)isLoadingMetadataForRemotePath:(NSString *)path
{
  path = [path lowercaseString];

  return [_pendingMetadata containsObject:path];
}

- (BOOL)isLoadingActivityMetadataForPath:(NSString *)path
{
  return [self isLoadingMetadataForRemotePath:
	  [_remoteActivityPath stringByAppendingPathComponent:path]];
}

- (void)reset
{
  BOOL metadata_empty = [_metadataCache count] == 0;
  BOOL db_empty = _database->items().size() == 0;

  if (!metadata_empty)
    {
      if (_oldMetadataCache == nil)
	_oldMetadataCache = [NSMutableDictionary dictionary];
      [_oldMetadataCache addEntriesFromDictionary:_metadataCache];
      [_metadataCache removeAllObjects];
    }

  if (!db_empty)
    {
      _database->clear();
      [_addedActivityRevisions removeAllObjects];
    }

  if (!metadata_empty)
    {
      [[NSNotificationCenter defaultCenter]
       postNotificationName:ActMetadataDatabaseDidChange object:self];
    }

  if (!db_empty)
    {
      [[NSNotificationCenter defaultCenter]
       postNotificationName:ActActivityDatabaseDidChange object:self];
    }
}

static NSDictionary *
metadata_dictionary(DBMetadata *meta)
{
  if ([meta isDeleted])
    return nil;

  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  if (id hash = [meta hash])
    [dict setObject:hash forKey:@"hash"];

  if (id rev = [meta rev])
    [dict setObject:rev forKey:@"rev"];

  if ([meta isDirectory])
    {
      NSMutableArray *contents = [NSMutableArray array];

      for (DBMetadata *sub in [meta contents])
	{
	  if ([sub isDeleted])
	    continue;

	  [contents addObject:
	   [[[sub path] lastPathComponent] lowercaseString]];
	}

      [dict setObject:contents forKey:@"contents"];
    }

  return dict;
}

- (void)restClient:(DBRestClient *)client loadedMetadata:(DBMetadata *)meta
{
  NSString *path = [[meta path] lowercaseString];

  [_pendingMetadata removeObject:path];

  if (NSDictionary *dict = metadata_dictionary(meta))
    {
      [_metadataCache setObject:dict forKey:path];
      [_oldMetadataCache removeObjectForKey:path];

      if ([meta isDirectory])
	{
	  /* We also were handed the full metadata for all files in
	     this directory, so may as well add it to the cache. */

	  for (DBMetadata *sub in [meta contents])
	    {
	      if ([sub isDirectory])
		continue;

	      NSString *path = [[sub path] lowercaseString];

	      if (NSDictionary *dict = metadata_dictionary(sub))
		[_metadataCache setObject:dict forKey:path];
	      else
		[_metadataCache removeObjectForKey:path];

	      [_oldMetadataCache removeObjectForKey:path];
	    }

	  /* FIXME: remove cache items under path that no longer exist? */
	}
    }
  else
    [_metadataCache setObject:[NSNull null] forKey:path];

  _metadataCacheNeedsSynchronize = YES;

  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActMetadataDatabaseDidChange object:self];
}

- (void)restClient:(DBRestClient *)client
    metadataUnchangedAtPath:(NSString *)path
{
  path = [path lowercaseString];

  NSLog(@"metadata %@ unchanged", path);

  if ([_metadataCache objectForKey:path] == nil)
    {
      id obj = [_oldMetadataCache objectForKey:path];

      if (obj == nil)
	{
	  obj = [NSNull null];
	  _metadataCacheNeedsSynchronize = YES;
	}

      [_metadataCache setObject:obj forKey:path];
      [_oldMetadataCache removeObjectForKey:path];
    }

  [_pendingMetadata removeObject:path];
}

- (void)restClient:(DBRestClient *)client
    loadMetadataFailedWithError:(NSError *)err
{
  NSLog(@"ERROR: load metadata %@", err);
}

- (void)loadActivityFromPath:(NSString *)path revision:(NSString *)rev
{
  NSString *src_path
    = [[_remoteActivityPath stringByAppendingPathComponent:path]
       lowercaseString];

  NSString *dest_path
    = [_localActivityPath stringByAppendingPathComponent:path];

  NSFileManager *fm = [NSFileManager defaultManager];

  if ([fm fileExistsAtPath:dest_path] && rev != nil
      && [[_activityRevisions objectForKey:path] isEqualToString:rev])
    {
      /* File is already cached and up to date. Add it to database
	 if not already done so. */

      NSString *added_rev = [_addedActivityRevisions objectForKey:path];

      if (![added_rev isEqualToString:rev])
	{
	  [_addedActivityRevisions setObject:rev forKey:path];

	  if (_database->add_activity([dest_path UTF8String]))
	    {
	      [[NSNotificationCenter defaultCenter]
	       postNotificationName:ActActivityDatabaseDidChange object:self];
	    }
	}
    }
  else if ([_pendingActivityRevisions objectForKey:path] == nil)
    {
      /* File needs to be brought into our cache. */

      [fm removeItemAtPath:dest_path error:nil];

      NSString *parent = [dest_path stringByDeletingLastPathComponent];
      [fm createDirectoryAtPath:parent withIntermediateDirectories:YES
       attributes:nil error:nil];

      NSLog(@"loading activity %@ from %@ (%@) to %@",
	    path, src_path, rev, dest_path);

      [_pendingActivityRevisions setObject:rev forKey:path];

#if 0
      /* FIXME: specifying the revision I got back from the loaded
	 metadata gives me a "404 - trying to load a directory"
	 error!? */

      [_dbClient loadFile:src_path atRev:rev intoPath:dest_path];
#else
      [_dbClient loadFile:src_path intoPath:dest_path];
#endif
    }
}

- (void)restClient:(DBRestClient *)client loadedFile:(NSString *)destPath
{
  if ([destPath hasPathPrefix:_localActivityPath])
    {
      NSString *path
        = [destPath stringByRemovingPathPrefix:_localActivityPath];

      NSString *rev = [_pendingActivityRevisions objectForKey:path];

      NSLog(@"loaded activity %@ to %@", path, destPath);

      if (rev != nil)
	{
	  [_pendingActivityRevisions removeObjectForKey:path];

	  [_activityRevisions setObject:rev forKey:path];
	  _activityRevisionsNeedsSynchronize = YES;

	  [_addedActivityRevisions setObject:rev forKey:path];

	  if (_database->add_activity([destPath UTF8String]))
	    {
	      [[NSNotificationCenter defaultCenter]
	       postNotificationName:ActActivityDatabaseDidChange object:self];
	    }
	}
      else
	NSLog(@"ERROR: unexpected activity file: %@ (rev = %@)", path, rev);
    }
}

- (void)restClient:(DBRestClient *)client
    loadFileFailedWithError:(NSError *)err
{
  NSString *destPath = [[err userInfo] objectForKey:@"destinationPath"];

  if ([destPath hasPathPrefix:_localActivityPath])
    {
      NSString *path
        = [destPath stringByRemovingPathPrefix:_localActivityPath];

      [_pendingActivityRevisions removeObjectForKey:path];
    }

  NSLog(@"ERROR: load file %@", err);
}

- (void)showQueryResults:(const act::database::query &)query
{
  std::vector<act::database::item *> items;
  [self database]->execute_query(query, items);

  BOOL selection = NO;

  _activityList.clear();

  for (auto &it : items)
    {
      _activityList.push_back(*it);

      if (it->storage() == _selectedActivityStorage)
	selection = YES;
    }

  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActActivityListDidChange object:self];

  if (!selection)
    [self setSelectedActivityStorage:nullptr];
}

- (const std::vector<act::database::item> &)activityList
{
  return _activityList;
}

- (void)setActivityList:(const std::vector<act::database::item> &)vec
{
  _activityList = vec;

  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActActivityListDidChange object:self];
}

- (act::activity_storage_ref)selectedActivityStorage
{
  return _selectedActivityStorage;
}

- (void)setSelectedActivityStorage:(act::activity_storage_ref)storage
{
  if (_selectedActivityStorage != storage)
    {
      _selectedActivityStorage = storage;
      _selectedActivity.reset();

      [self selectedActivityDidChange];
    }
}

- (act::activity *)selectedActivity
{
  if (_selectedActivity == nullptr && _selectedActivityStorage != nullptr)
    _selectedActivity.reset(new act::activity(_selectedActivityStorage));

  return _selectedActivity.get();
}

- (void)selectedActivityDidChange
{
  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActSelectedActivityDidChange object:self];
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

- (NSString *)bodyString
{
  if (const act::activity *a = [self selectedActivity])
    return [self bodyStringOfActivity:*a];
  else
    return @"";
}

- (void)setBodyString:(NSString *)str
{
  if (act::activity *a = [self selectedActivity])
    [self setBodyString:str ofActivity:*a];
}

- (NSDate *)dateField
{
  if (const act::activity *a = [self selectedActivity])
    return [NSDate dateWithTimeIntervalSince1970:a->date()];
  else
    return nil;
}

- (void)setDateField:(NSDate *)date
{
  NSString *value = nil;

  if (date != nil)
    {
      std::string str;
      act::format_date_time(str, (time_t) [date timeIntervalSince1970]);
      value = [NSString stringWithUTF8String:str.c_str()];
    }

  [self setString:value forField:@"Date"];
}

- (NSString *)stringForField:(NSString *)name
{
  if (const act::activity *a = [self selectedActivity])
    return [self stringForField:name ofActivity:*a];
  else
    return nil;
}

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

- (BOOL)isFieldReadOnly:(NSString *)name
{
  if (const act::activity *a = [self selectedActivity])
    return [self isFieldReadOnly:name ofActivity:*a];
  else
    return YES;
}

- (BOOL)isFieldReadOnly:(NSString *)name ofActivity:(const act::activity &)a
{
  return a.storage()->field_read_only_p([name UTF8String]);
}

- (void)setString:(NSString *)str forField:(NSString *)name
{
  if (act::activity *a = [self selectedActivity])
    [self setString:str forField:name ofActivity:*a];
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

- (void)deleteField:(NSString *)name
{
  if (act::activity *a = [self selectedActivity])
    [self deleteField:name ofActivity:*a];
}

- (void)deleteField:(NSString *)name ofActivity:(act::activity &)a
{
  [self setString:nil forField:name ofActivity:a];
}

- (void)renameField:(NSString *)oldName to:(NSString *)newName
{
  if (act::activity *a = [self selectedActivity])
    [self renameField:oldName to:newName ofActivity:*a];
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
