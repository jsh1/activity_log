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

#import <Foundation/Foundation.h>
#import "DBRestClient.h"

extern NSString *const ActMetadataCacheDidChange;
extern NSString *const ActFileCacheDidChange;

@interface ActFileManager : NSObject <DBRestClientDelegate>
{
  DBRestClient *_dbClient;

  NSString *_localFilePath;

  BOOL _queuedSynchronize;

  /* Dropbox metadata caching. */

  NSMutableSet *_pendingMetadata;
  NSMutableDictionary *_metadataCache;		/* path -> NSDictionary */
  NSMutableDictionary *_oldMetadataCache;

  NSString *_metadataCachePath;
  BOOL _metadataCacheNeedsSynchronize;

  /* Dropbox file caching. */

  NSMutableDictionary *_fileCacheRevisions;	/* path -> NSNumber<int> */
  NSMutableDictionary *_pendingFileCacheRevisions;

  NSString *_fileCacheRevisionsPath;
  BOOL _fileCacheRevisionsNeedsSynchronize;

  /* Upload state. */

  NSMutableDictionary *_pendingFileUploads;	/* path -> block(BOOL) */
}

+ (ActFileManager *)sharedManager;

+ (void)shutdownSharedManager;

@property(nonatomic, readonly) BOOL needsSynchronize;

- (void)reset;

- (void)synchronize;

- (void)invalidate;

/* These return nil if loading asynchronously, in which case will post
   ActMetadataCacheDidChange when the metadata-read finishes. */

- (NSDictionary *)metadataForRemotePath:(NSString *)path;

/* Returns the local path of the file, or nil if it's still being
   loaded, in which case ActFileCacheDidChange will be posted once it's
   available. */

- (NSString *)localPathForRemotePath:(NSString *)path revision:(NSString *)rev;

/* The inverse mapping. */

- (NSString *)remotePathForLocalPath:(NSString *)path;

/* Returns NO if the upload was not started (e.g. there's already an upload
   to the same destination file in progress). If non-nil 'block' is called
   with the new revision of the file, or nil if an error occurred. */

- (BOOL)copyItemAtLocalPath:(NSString *)src_path
    toRemotePath:(NSString *)dest_path previousRevision:(NSString *)rev
    completion:(void (^)(BOOL))block;

@end
