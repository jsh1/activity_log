// -*- c-style: gnu -*-

#import <Foundation/Foundation.h>

@class ActURLCache, ActCachedURL;

@protocol ActURLCacheDelegate <NSObject>

- (void)cachedURLDidFinish:(ActCachedURL *)url;

@end

@interface ActCachedURL : NSObject
{
  NSURL *_url;
  id<ActURLCacheDelegate> _delegate;
  id _userInfo;
  ActURLCache *_cache;
  NSURLConnection *_connection;
  NSMutableData *_data;
  NSError *_error;
  BOOL _dispatching;
}

- (void)cancel;

@property(nonatomic, copy) NSURL *URL;
@property(nonatomic, assign) id<ActURLCacheDelegate> delegate;
@property(nonatomic, retain) id userInfo;

@property(nonatomic, readonly) ActURLCache *cache;
@property(nonatomic, readonly) NSData *data;
@property(nonatomic, readonly) NSError *error;

@end

@interface ActURLCache : NSObject
{
  NSString *_path;
  void *_handle;
  void *_queryStmt;
  void *_insertStmt;
}

+ (ActURLCache *)sharedURLCache;

- (id)initWithPath:(NSString *)path;

- (BOOL)loadURL:(ActCachedURL *)url;

- (void)insertData:(NSData *)data forURL:(NSURL *)url;

- (void)pruneCaches;
- (void)emptyCaches;

@end
