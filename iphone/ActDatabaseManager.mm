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
#import "ActFileManager.h"

#import "act-config.h"
#import "act-format.h"
#import "act-gps-activity.h"

#import "FoundationExtensions.h"

#define BODY_WRAP_COLUMN 72
#define SYNC_DELAY_NS (10LL*NSEC_PER_SEC)

NSString *const ActActivityDatabaseDidChange = @"ActActivityDatabaseDidChange";
NSString *const ActActivityDidChange = @"ActActivityDidChange";

#if DEBUG && !defined(VERBOSE)
# define VERBOSE 1
#endif

#define LOG(x) do {if (VERBOSE) NSLog x;} while (0)

@implementation ActDatabaseManager

@synthesize fileManager = _fileManager;

- (id)initWithFileManager:(ActFileManager *)file_manager
{
  self = [super init];
  if (self == nil)
    return nil;

  _fileManager = file_manager;

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(fileCacheDidChange:)
   name:ActFileCacheDidChange object:_fileManager];

  /* Can't just reload() the entire cached database directory, it may
     include files that no longer exist in the master store, we'll
     manually call add_activity() for every file. */

  _database.reset(new act::database());

  _addedActivityRevisions = [NSMutableDictionary dictionary];

  return self;
}

- (void)invalidate
{
  [self synchronize];

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  _fileManager = nil;
}

- (void)dealloc
{
  [self invalidate];
}

- (BOOL)needsSynchronize
{
  return _databaseNeedsSynchronize || _fileManager.needsSynchronize;
}

- (void)synchronize
{
  if (_databaseNeedsSynchronize)
    {
      ActAppDelegate *delegate
	= (id)[UIApplication sharedApplication].delegate;

      for (auto &it : _database->items())
	{
	  act::activity_storage_ref storage = it.storage();

	  if (storage->seed() != storage->path_seed())
	    {
	      NSString *src = [delegate temporaryLocalFile];

	      if (storage->write_file([src fileSystemRepresentation]))
		{
		  NSString *local_path = [NSString stringWithUTF8String:
					  it.storage()->path()];
		  NSString *path = [local_path stringByRemovingPathPrefix:
				    delegate.remoteActivityPath];
		  NSString *rev = _addedActivityRevisions[path];

		  BOOL ret = [_fileManager copyItemAtLocalPath:src
			      toRemotePath:path previousRevision:rev
			      completion:^(NSString *rev)
			        {
				  [[NSFileManager defaultManager]
				   removeItemAtPath:src error:nil];

				  if (rev != nil)
				    _addedActivityRevisions[path] = rev;
				  else
				    storage->increment_seed();
				}];

		  if (ret)
		    storage->set_path_seed(storage->seed());
		}
	    }
	}
    }

  [_fileManager synchronize];
}

- (act::database *)database
{
  return _database.get();
}

- (void)reset
{
  BOOL db_empty = _database->items().size() == 0;

  _database->clear();

  [_addedActivityRevisions removeAllObjects];

  [_fileManager reset];

  if (!db_empty)
    {
      [[NSNotificationCenter defaultCenter]
       postNotificationName:ActActivityDatabaseDidChange object:self];
    }
}

- (void)loadActivityFromPath:(NSString *)rel_path revision:(NSString *)rev
{
  ActAppDelegate *delegate = (id)[UIApplication sharedApplication].delegate;

  NSString *path = [delegate remoteActivityPath:rel_path];

  NSString *dest = [_fileManager localPathForRemotePath:path revision:rev];

  if (dest != nil)
    {
      /* File is already cached and up to date. Add it to database
	 if not already done so. */

      NSString *added_rev = _addedActivityRevisions[path];

      if (![added_rev isEqualToString:rev])
	{
	  _addedActivityRevisions[path] = rev;

	  if (_database->add_activity([dest UTF8String]))
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

- (void)fileCacheDidChange:(NSNotification *)note
{
  ActAppDelegate *delegate = (id)[UIApplication sharedApplication].delegate;

  NSDictionary *info = [note userInfo];
  NSString *path = info[@"remotePath"];
  NSString *rev = info[@"rev"];

  if ([path hasPathPrefix:delegate.remoteActivityPath caseInsensitive:YES])
    {
      _addedActivityRevisions[path] = rev;

      NSString *dest = info[@"localPath"];
      if (_database->add_activity([dest fileSystemRepresentation]))
	{
	  [[NSNotificationCenter defaultCenter]
	   postNotificationName:ActActivityDatabaseDidChange object:self];
	}
    }
}

- (void)activityDidChange:(const act::activity_storage_ref)a
{
  _databaseNeedsSynchronize = YES;

  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActActivityDidChange object:self
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

  [self activityDidChange:a.storage()];
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

  [self activityDidChange:a.storage()];
  [self activityDidChange:a.storage()];
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

      [self activityDidChange:a.storage()];
    }
}

@end
