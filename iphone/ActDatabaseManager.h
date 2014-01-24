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
#import "act-database.h"
#import "DBRestClient.h"
#import <memory>

extern NSString *const ActMetadataCacheDidChange;
extern NSString *const ActActivityDatabaseDidChange;
extern NSString *const ActActivityDidChangeField;
extern NSString *const ActActivityDidChangeBody;

@interface ActDatabaseManager : NSObject <DBRestClientDelegate>
{
  DBRestClient *_dbClient;

  NSString *_localActivityPath;
  NSString *_remoteActivityPath;

  std::unique_ptr<act::database> _database;

  NSMutableSet *_pendingMetadata;
  NSMutableDictionary *_metadataCache;		/* path -> NSDictionary */
  NSMutableDictionary *_oldMetadataCache;

  NSString *_metadataCachePath;
  BOOL _metadataCacheNeedsSynchronize;

  NSMutableDictionary *_activityRevisions;	/* path -> NSNumber<int> */
  NSMutableDictionary *_pendingActivityRevisions;
  NSMutableDictionary *_addedActivityRevisions;

  NSString *_activityRevisionsPath;
  BOOL _activityRevisionsNeedsSynchronize;
}

+ (ActDatabaseManager *)sharedManager;

+ (void)shutdownSharedManager;

@property(nonatomic, readonly) BOOL needsSynchronize;

- (void)reset;

- (void)synchronize;

- (void)invalidate;

/* These return nil if loading asynchronously, in which case will post
   ActMetadataCacheDidChange when the metadata-read finishes. */

- (NSDictionary *)metadataForRemotePath:(NSString *)path;
- (NSDictionary *)activityMetadataForPath:(NSString *)path;

- (BOOL)isLoadingMetadataForRemotePath:(NSString *)path;
- (BOOL)isLoadingActivityMetadataForPath:(NSString *)path;

/* ActActivityDatabaseDidChange will be posted once the file is in
   the database. */

- (void)loadActivityFromPath:(NSString *)path revision:(NSString *)rev;

@property(nonatomic, readonly) act::database *database;

- (void)activityDidChangeBody:(const act::activity_storage_ref)storage;

- (void)activity:(const act::activity_storage_ref)storage
    didChangeField:(NSString *)name;

@end

@interface ActDatabaseManager (ActivityFields)

- (NSString *)bodyStringOfActivity:(const act::activity &)a;

- (void)setBodyString:(NSString *)str ofActivity:(act::activity &)a;

- (NSString *)stringForField:(NSString *)name
    ofActivity:(const act::activity &)a;

- (BOOL)isFieldReadOnly:(NSString *)name ofActivity:(const act::activity &)a;

- (void)setString:(NSString *)str forField:(NSString *)name
    ofActivity:(act::activity &)a;

- (void)deleteField:(NSString *)name ofActivity:(act::activity &)a;

- (void)renameField:(NSString *)oldName to:(NSString *)newName
    ofActivity:(act::activity &)a;

@end
