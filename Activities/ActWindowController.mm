// -*- c-style: gnu -*-

#import "ActWindowController.h"

#import "ActActivityListView.h"
#import "ActActivityViewController.h"

#import "act-format.h"

#define BODY_WRAP_COLUMN 72

@implementation ActWindowController

@synthesize undoManager = _undoManager;

- (NSString *)windowNibName
{
  return @"ActWindow";
}

- (id)init
{
  self = [super initWithWindow:nil];
  if (self == nil)
    return nil;

  _activityViewController = [[ActActivityViewController alloc] init];
  [_activityViewController setController:self];

  _undoManager = [[NSUndoManager alloc] init];

  return self;
}

- (void)dealloc
{
  [_activityViewController release];
  [_undoManager release];

  [super dealloc];
}

- (act::database *)database
{
  if (!_database)
    _database.reset (new act::database());

  return _database.get();
}

- (act::activity_storage_ref)selectedActivity
{
  return [_activityListView selectedActivity];
}

- (void)setSelectedActivity:(act::activity_storage_ref)a
{
  [_activityListView setSelectedActivity:a];

  if (a == nullptr)
    [[_activityViewController view] setHidden:YES];

  [_activityViewController setActivityStorage:a];

  if (a != nullptr)
    [[_activityViewController view] setHidden:NO];
}

- (void)setNeedsSynchronize:(BOOL)flag
{
  if (flag && !_needsSynchronize)
    {
      _needsSynchronize = YES;

      dispatch_time_t t = dispatch_time(DISPATCH_TIME_NOW, 2LL * NSEC_PER_SEC);
      dispatch_after(t, dispatch_get_main_queue(), ^{
	if (_needsSynchronize)
	  [self synchronize];
      });
    }
}

- (BOOL)needsSynchronize
{
  return _needsSynchronize;
}

- (void)synchronize
{
  _needsSynchronize = NO;

  if (_database)
    _database->synchronize();
}

- (void)activity:(const act::activity_storage_ref)a
    didChangeField:(NSString *)name;
{
  [self setNeedsSynchronize:YES];

  [_activityListView reloadActivity:a];

  if (a == [self selectedActivity])
    [_activityViewController activityDidChangeField:name];
}

- (void)activityDidChangeBody:(const act::activity_storage_ref)a
{
  [self setNeedsSynchronize:YES];

  if (a == [self selectedActivity])
    [_activityViewController activityDidChangeBody];
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

- (BOOL)isFieldReadOnly:(NSString *)name ofActivity:(const act::activity &)a
{
  return a.storage()->field_read_only_p([name UTF8String]);
}

- (void)setString:(NSString *)str forField:(NSString *)name
    ofActivity:(act::activity &)a
{
  auto id = act::lookup_field_id([name UTF8String]);
  const char *field_name = act::canonical_field_name(id);

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

- (void)renameField:(NSString *)oldName to:(NSString *)newName
    ofActivity:(act::activity &)a
{
  a.storage()->set_field_name([oldName UTF8String], [newName UTF8String]);

  [self activity:a.storage() didChangeField:oldName];
  [self activity:a.storage() didChangeField:newName];
}

- (NSString *)bodyStringOfActivity:(const act::activity &)a
{
  const std::string &s = a.body();

  if (s.size() != 0)
    {
      NSMutableString *str = [[NSMutableString alloc] init];

      const char *ptr = s.c_str();

      while (const char *eol = strchr(ptr, '\n'))
	{
	  NSString *tem = [[NSString alloc] initWithBytes:ptr
			   length:eol-ptr encoding:NSUTF8StringEncoding];
	  [str appendString:tem];
	  [tem release];
	  ptr = eol + 1;
	  if (eol[1] == '\n')
	    [str appendString:@"\n\n"], ptr++;
	  else if (eol[1] != 0)
	    [str appendString:@" "];
	}

      if (*ptr != 0)
	{
	  NSString *tem = [[NSString alloc] initWithUTF8String:ptr];
	  [str appendString:tem];
	  [tem release];
	}

      return [str autorelease];
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
	  if (column >= BODY_WRAP_COLUMN)
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

	  if (word[0] == '\n' && word[1] == '\n')
	    {
	      wrapped.push_back('\n');
	      column = BODY_WRAP_COLUMN;
	    }
	  else
	    column += word - ptr;

	  ptr = word;
	}

      if (ptr[0] != 0)
	ptr++;
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

- (void)windowDidLoad
{
  if (NSView *view = [_activityViewController view])
    {
      [view setFrame:[_mainContentView bounds]];
      [view setHidden:YES];
      [_mainContentView addSubview:view];
    }

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(windowWillClose:)
   name:NSWindowWillCloseNotification object:[self window]];

  // FIXME: only while bootstrapping

  act::database::query query;
  query.add_date_range(act::date_range(0, time(nullptr)));

  std::vector<act::database::item *> items;
  [self database]->execute_query(query, items);

  std::vector<act::activity_storage_ref> activities;

  for (auto &it : items)
    activities.push_back(it->storage());

  [_activityListView setActivities:activities];
  if (activities.size() != 0)
    [self setSelectedActivity:activities[0]];
}

- (void)windowWillClose:(NSNotification *)note
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [NSApp terminate:self];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
  return _undoManager;
}

@end
