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

@class ActURLCache, ActCachedURL;

@protocol ActURLCacheDelegate <NSObject>

- (void)cachedURLDidFinish:(ActCachedURL *)url;

@end

@interface ActCachedURL : NSObject

- (void)cancel;

@property(nonatomic, copy) NSURL *URL;
@property(nonatomic, weak) id<ActURLCacheDelegate> delegate;
@property(nonatomic, strong) id userInfo;

@property(nonatomic, strong, readonly) ActURLCache *cache;
@property(nonatomic, copy, readonly) NSData *data;
@property(nonatomic, copy, readonly) NSError *error;

@end

@interface ActURLCache : NSObject

+ (ActURLCache *)sharedURLCache;

- (id)initWithPath:(NSString *)path;

- (BOOL)loadURL:(ActCachedURL *)url;

- (void)pruneCaches;
- (void)emptyCaches;

@end
