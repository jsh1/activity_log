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

#import "ActFileManager.h"

#import "ActAppDelegate.h"

#import "act-config.h"
#import "act-format.h"
#import "act-gps-activity.h"

#import "DropboxSDK.h"

#import "FoundationExtensions.h"

NSString *const ActMetadataCacheDidChange = @"ActMetadataCacheDidChange";
NSString *const ActFileCacheDidChange = @"ActFileCacheDidChange";

#define SYNC_DELAY_NS (10LL*NSEC_PER_SEC)

#ifndef VERBOSE
# define VERBOSE 0
#endif

#define LOG(x) do {if (VERBOSE) NSLog x;} while (0)

@implementation ActFileManager

static ActFileManager *_sharedManager;

+ (ActFileManager *)sharedManager
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

  NSString *cache_dir = [[[NSSearchPathForDirectoriesInDomains
			   (NSCachesDirectory, NSUserDomainMask, YES)
			   firstObject] stringByAppendingPathComponent:
			  [[NSBundle mainBundle] bundleIdentifier]]
			 stringByAppendingPathComponent:@"ActFileManager"];

  _localFilePath = [cache_dir stringByAppendingPathComponent:@"files"];

  _pendingMetadata = [NSMutableSet set];
  _metadataCache = [NSMutableDictionary dictionary];
  _metadataCachePath = [cache_dir stringByAppendingPathComponent:
			@"metadata.json"];

  if (NSData *data = [NSData dataWithContentsOfFile:_metadataCachePath])
    {
      _oldMetadataCache = [[NSJSONSerialization JSONObjectWithData:data
			    options:0 error:nil] mutableCopy];
    }

  _fileCacheRevisionsPath = [cache_dir stringByAppendingPathComponent:
			     @"revisions.json"];

  if (NSData *data = [NSData dataWithContentsOfFile:_fileCacheRevisionsPath])
    {
      _fileCacheRevisions = [[NSJSONSerialization JSONObjectWithData:data
			      options:0 error:nil] mutableCopy];
    }

  if (_fileCacheRevisions == nil)
    _fileCacheRevisions = [NSMutableDictionary dictionary];

  _pendingFileCacheRevisions = [NSMutableDictionary dictionary];

  _pendingFileUploads = [NSMutableDictionary dictionary];

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

- (void)synchronizeAfterDelay
{
  if (!_queuedSynchronize)
    {
      _queuedSynchronize = YES;

      dispatch_time_t t = dispatch_time(DISPATCH_TIME_NOW, SYNC_DELAY_NS);

      dispatch_after(t, dispatch_get_main_queue(), ^{
	_queuedSynchronize = NO;
	[self synchronize];
      });
    }
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

  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActMetadataCacheDidChange object:self];
}

static NSDictionary *
file_metadata_dictionary(DBMetadata *sub)
{
  if (sub.isDeleted)
    return nil;

  NSMutableDictionary *sub_dict = [NSMutableDictionary dictionary];

  sub_dict[@"name"] = [sub.path lastPathComponent];

  /* Note: not including hash field, we only use it to avoid receiving
     directory metadata redundantly. */

  if (id rev = sub.rev)
    sub_dict[@"rev"] = rev;

  if (sub.isDirectory)
    sub_dict[@"directory"] = @YES;

  return sub_dict;
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
      if (NSDictionary *sub_dict = file_metadata_dictionary(sub))
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

  [self synchronizeAfterDelay];

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

	  [self synchronizeAfterDelay];
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

      [self synchronizeAfterDelay];

      [[NSNotificationCenter defaultCenter]
       postNotificationName:ActFileCacheDidChange object:self
       userInfo:@{@"remotePath": path, @"localPath": destPath, @"rev": rev}];
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

- (BOOL)copyItemAtLocalPath:(NSString *)src_path
    toRemotePath:(NSString *)dest_path previousRevision:(NSString *)rev
    completion:(void (^)(NSString *rev))block
{
  assert(![src_path hasPathPrefix:_localFilePath]);

  if (_pendingFileUploads[dest_path] != nil)
    return NO;

  _pendingFileUploads[dest_path] = block ? [block copy] : [NSNull null];

  [_dbClient uploadFile:[dest_path lastPathComponent]
   toPath:[dest_path stringByDeletingLastPathComponent]
   withParentRev:rev fromPath:src_path];

  return YES;
}

- (void)restClient:(DBRestClient *)client uploadedFile:(NSString *)destPath
    from:(NSString *)srcPath metadata:(DBMetadata *)meta
{
  id completion = _pendingFileUploads[destPath];

  if (completion != nil)
    {
      [_pendingFileUploads removeObjectForKey:destPath];

      /* Insert new file metadata into our cache. */

      NSString *dir = [destPath stringByDeletingLastPathComponent];
      NSString *file = [destPath lastPathComponent];

      if (NSMutableDictionary *dict = [_metadataCache[dir] mutableCopy])
	{
	  NSMutableArray *contents = [dict[@"contents"] mutableCopy];
	  NSInteger count = [contents count], idx;

	  for (idx = 0; idx < count; idx++)
	    {
	      NSDictionary *sub_dict = contents[idx];

	      if ([sub_dict[@"name"] isEqualToString:file caseInsensitive:YES])
		{
		  contents[idx] = file_metadata_dictionary(meta);
		  break;
		}
	    }

	  if (idx == count)
	    [contents addObject:file_metadata_dictionary(meta)];

	  dict[@"contents"] = contents;
	  _metadataCache[dir] = dict;

	  _metadataCacheNeedsSynchronize = YES;
	  [self synchronizeAfterDelay];
	}

      /* Call completion handler with new file revision. */

      if (![completion isKindOfClass:[NSNull class]])
	{
	  void (^block)(NSString *rev) = completion;
	  block(meta.rev);
	}
    }
}

- (void)restClient:(DBRestClient *)client
    uploadFileFailedWithError:(NSError *)error
{
  NSString *destPath = [error userInfo][@"destinationPath"];

  id completion = _pendingFileUploads[destPath];

  if (completion != nil)
    {
      [_pendingFileUploads removeObjectForKey:destPath];

      if (![completion isKindOfClass:[NSNull class]])
	{
	  void (^block)(NSString *rev) = completion;
	  block(nil);
	}
    }
}

@end
