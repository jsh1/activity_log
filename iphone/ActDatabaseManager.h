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
#import <memory>

extern NSString *const ActActivityDatabaseDidChange;
extern NSString *const ActActivityDidChangeField;
extern NSString *const ActActivityDidChangeBody;

@class ActFileManager;

@interface ActDatabaseManager : NSObject
{
  ActFileManager *_fileManager;

  std::unique_ptr<act::database> _database;

  BOOL _databaseNeedsSynchronize;

  /* Activity database contents. */

  NSMutableDictionary *_addedActivityRevisions;
}

- (id)initWithFileManager:(ActFileManager *)fileManager;

@property(nonatomic, readonly) ActFileManager *fileManager;
@property(nonatomic, readonly) BOOL needsSynchronize;

- (void)reset;

- (void)synchronize;

- (void)invalidate;

/* ActActivityDatabaseDidChange will be posted once the file is in
   the database (i.e. may be asynchronous to the call). */

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
