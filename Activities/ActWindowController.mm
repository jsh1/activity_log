// -*- c-style: gnu -*-

#import "ActWindowController.h"

#import "ActChartViewController.h"
#import "ActLapViewController.h"
#import "ActListViewController.h"
#import "ActNotesListViewController.h"
#import "ActMapViewController.h"
#import "ActSummaryViewController.h"
#import "ActSplitView.h"
#import "ActTextField.h"

#import "act-config.h"
#import "act-format.h"
#import "act-new.h"

#define BODY_WRAP_COLUMN 72

NSString *const ActActivityListDidChange = @"ActActivityListDidChange";
NSString *const ActSelectedActivityDidChange = @"ActSelectedActivityDidChange";
NSString *const ActSelectedLapIndexDidChange = @"ActSelectedLapIndexDidChange";
NSString *const ActActivityDidChangeField = @"ActActivityDidChangeField";
NSString *const ActActivityDidChangeBody = @"ActActivityDidChangeBody";

@implementation ActWindowController

@synthesize undoManager = _undoManager;

- (NSString *)windowNibName
{
  return @"ActWindow";
}

- (ActViewController *)viewControllerWithClass:(Class)cls
{
  for (ActViewController *obj in _viewControllers)
    {
      if ([obj isKindOfClass:cls])
	return obj;
    }

  if (ActViewController *obj = [[cls alloc] initWithController:self])
    {
      [_viewControllers addObject:obj];
      [obj release];
      return obj;
    }
  else
    return nil;
}

- (id)init
{
  self = [super initWithWindow:nil];
  if (self == nil)
    return nil;

  _viewControllers = [[NSMutableArray alloc] init];
  _splitViews = [[NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory
		  valueOptions:NSMapTableWeakMemory] retain];
  _undoManager = [[NSUndoManager alloc] init];

  _selectedLapIndex = -1;

  return self;
}

- (void)windowDidLoad
{
  [self addSplitView:_outerSplitView identifier:@"Window.outerSplitView"];
  [self addSplitView:_leftSplitView identifier:@"Window.leftSplitView"];
  [self addSplitView:_leftRightSplitView identifier:@"Window.leftRightSplitView"];
  [self addSplitView:_rightSplitView identifier:@"Window.rightSplitView"];

  _fieldEditor = [[ActFieldEditor alloc] initWithFrame:NSZeroRect];
  [_fieldEditor setFieldEditor:YES];

  if (ActViewController *obj
      = [self viewControllerWithClass:[ActListViewController class]])
    {
      [obj addToContainerView:_topLeftContainer];
      [[self window] setInitialFirstResponder:[obj initialFirstResponder]];
    }

  if (ActViewController *obj
      = [self viewControllerWithClass:[ActNotesListViewController class]])
    {
      [obj addToContainerView:_topLeftContainer];
      [[self window] setInitialFirstResponder:[obj initialFirstResponder]];
    }

  if (ActViewController *obj
      = [self viewControllerWithClass:[ActSummaryViewController class]])
    {
      [obj addToContainerView:_bottomLeftContainer];
    }

  if (ActViewController *obj
      = [self viewControllerWithClass:[ActMapViewController class]])
    {
      [obj addToContainerView:_topRightContainer];
    }

  if (ActViewController *obj
      = [self viewControllerWithClass:[ActLapViewController class]])
    {
      [obj addToContainerView:_middleRightContainer];
    }

  if (ActViewController *obj
      = [self viewControllerWithClass:[ActChartViewController class]])
    {
      [obj addToContainerView:_bottomRightContainer];
    }

  [self applySavedWindowState];

  [self controlAction:_listViewControl];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(windowWillClose:)
   name:NSWindowWillCloseNotification object:[self window]];

  [self loadActivities];
}

- (void)dealloc
{
  [_viewControllers release];
  [_splitViews release];
  [_undoManager release];
  [_fieldEditor release];

  [super dealloc];
}

- (void)addSplitView:(ActSplitView *)view identifier:(NSString *)ident
{
  [_splitViews setObject:ident forKey:view];
}

- (void)removeSplitView:(ActSplitView *)view
{
  [_splitViews removeObjectForKey:view];
}

- (void)saveWindowState
{
  if (![self isWindowLoaded] || [self window] == nil)
    return;

  NSMutableDictionary *controllers = [NSMutableDictionary dictionary];

  for (ActViewController *controller in _viewControllers)
    {
      if (NSDictionary *sub = [controller savedViewState])
	[controllers setObject:sub forKey:[controller identifier]];
    }

  NSMutableDictionary *split = [NSMutableDictionary dictionary];

  for (ActSplitView *view in _splitViews)
    {
      NSString *ident = [_splitViews objectForKey:view];
      if (NSDictionary *sub = [view savedViewState])
	[split setObject:sub forKey:ident];
    }

  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
			controllers, @"ActViewControllers",
			split, @"ActSplitViews",
			[NSNumber numberWithInt:
			 [_listViewControl selectedSegment]],
			@"ActSelectedListView",
			nil];

  [[NSUserDefaults standardUserDefaults]
   setObject:dict forKey:@"ActSavedWindowState"];
}

- (void)applySavedWindowState
{
  NSDictionary *state = [[NSUserDefaults standardUserDefaults]
			 dictionaryForKey:@"ActSavedWindowState"];
  if (state == nil)
    return;

  if (NSDictionary *dict = [state objectForKey:@"ActViewControllers"])
    {
      for (ActViewController *controller in _viewControllers)
	{
	  if (NSDictionary *sub = [dict objectForKey:[controller identifier]])
	    [controller applySavedViewState:sub];
	}
    }

  if (NSDictionary *dict = [state objectForKey:@"ActSplitViews"])
    {
      for (ActSplitView *view in _splitViews)
	{
	  NSString *ident = [_splitViews objectForKey:view];
	  if (NSDictionary *sub = [dict objectForKey:ident])
	    [view applySavedViewState:sub];
	}
    }

  if (NSNumber *obj = [state objectForKey:@"ActSelectedListView"])
    [_listViewControl setSelectedSegment:[obj intValue]];
}

- (act::database *)database
{
  if (!_database)
    _database.reset (new act::database());

  return _database.get();
}

- (void)loadActivities
{
  // FIXME: only while bootstrapping

  act::database::query query;
  query.add_date_range(act::date_range(0, time(nullptr)));

  std::vector<act::database::item *> items;
  [self database]->execute_query(query, items);

  _activityList.clear();
  for (auto &it : items)
    _activityList.push_back(it->storage());

  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActActivityListDidChange object:self];

  if (_activityList.size() != 0)
    [self setSelectedActivityStorage:_activityList[0]];
  else
    [self setSelectedActivityStorage:nullptr];
}

- (void)reloadActivities
{
  [self setSelectedActivityStorage:nullptr];

  [self database]->reload();

  [self loadActivities];
}

- (const std::vector<act::activity_storage_ref> &)activityList
{
  return _activityList;
}

- (void)setActivityList:(const std::vector<act::activity_storage_ref> &)vec
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

- (NSInteger)selectedLapIndex
{
  return _selectedLapIndex;
}

- (void)setSelectedLapIndex:(NSInteger)idx
{
  if (_selectedLapIndex != idx)
    {
      _selectedLapIndex = idx;

      [self selectedLapDidChange];
    }
}

- (void)setNeedsSynchronize:(BOOL)flag
{
  if (flag && !_needsSynchronize)
    {
      _needsSynchronize = YES;

      dispatch_time_t t = dispatch_time(DISPATCH_TIME_NOW, 2LL * NSEC_PER_SEC);
      dispatch_after(t, dispatch_get_main_queue(), ^{
	[self synchronizeIfNeeded];
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

- (void)synchronizeIfNeeded
{
  if (_needsSynchronize)
    [self synchronize];
}

- (void)selectedActivityDidChange
{
  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActSelectedActivityDidChange object:self];
}

- (void)selectedLapDidChange
{
  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActSelectedLapIndexDidChange object:self];
}

- (void)activity:(const act::activity_storage_ref)a
    didChangeField:(NSString *)name;
{
  [self setNeedsSynchronize:YES];

  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActActivityDidChangeField object:self
   userInfo:@{@"activity": [NSValue valueWithPointer:&a], @"field": name}];
}

- (void)activityDidChangeBody:(const act::activity_storage_ref)a
{
  [self setNeedsSynchronize:YES];

  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActActivityDidChangeField object:self
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

- (IBAction)newActivity:(id)sender
{
  if (sender == _addButton
      && ([[[self window] currentEvent] modifierFlags] & NSAlternateKeyMask))
    {
      return [self importFile:sender];
    }

  [self synchronizeIfNeeded];

  act::arguments args("act-new");
  args.push_back("--date");
  args.push_back("now");

  act::act_new(args);

  [self reloadActivities];
}

- (IBAction)importFile:(id)sender
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];

  NSString *default_dir = [[NSUserDefaults standardUserDefaults]
			   stringForKey:@"ActLastGPSImportDirectory"];
  if (default_dir == nil)
    {
      if (const char *path = act::shared_config().gps_file_dir())
	default_dir = [NSString stringWithUTF8String:path];
    }

  [panel setAllowedFileTypes:@[@"fit", @"tcx"]];
  [panel setAllowsMultipleSelection:YES];
  [panel setDirectoryURL:[NSURL fileURLWithPath:default_dir]];
  [panel setPrompt:@"Import"];
  [panel setTitle:@"Select FIT/TCX Files to Import"];

  [panel beginWithCompletionHandler:
   ^(NSInteger status) {
     if (status == NSFileHandlingPanelOKButton)
       {
	 NSArray *urls = [panel URLs];

	 for (NSURL *url in urls)
	   {
	     if (![url isFileURL])
	       continue;

	     act::arguments args("act-new");
	     args.push_back("--gps-file");
	     args.push_back([[url path] UTF8String]);

	     act::act_new(args);
	   }

	 [self reloadActivities];

	 if ([urls count] != 0)
	   {
	     [[NSUserDefaults standardUserDefaults] setObject:
	      [[[urls lastObject] path] stringByDeletingLastPathComponent]
	      forKey:@"ActLastGPSImportDirectory"];
	   }
       }
   }];
}

- (IBAction)delete:(id)sender
{
}

- (IBAction)reloadDatabase:(id)sender
{
  [self reloadActivities];
}

- (IBAction)editActivity:(id)sender
{
  [[self window] makeFirstResponder:
   [[self viewControllerWithClass:[ActSummaryViewController class]]
    initialFirstResponder]];
}

- (IBAction)nextActivity:(id)sender
{
  auto it = std::find(_activityList.begin(), _activityList.end(),
		      _selectedActivityStorage);

  if (++it < _activityList.end())
    [self setSelectedActivityStorage:*it];
  else
    NSBeep();
}

- (IBAction)previousActivity:(id)sender
{
  auto it = std::find(_activityList.begin(), _activityList.end(),
		      _selectedActivityStorage);

  if (--it >= _activityList.begin())
    [self setSelectedActivityStorage:*it];
  else
    NSBeep();
}

- (IBAction)firstActivity:(id)sender
{
  if (_activityList.size() > 0)
    [self setSelectedActivityStorage:_activityList.front()];
}

- (IBAction)lastActivity:(id)sender
{
  if (_activityList.size() > 0)
    [self setSelectedActivityStorage:_activityList.back()];
}

- (IBAction)controlAction:(id)sender
{
  if (sender == _listViewControl)
    {
      [[[self viewControllerWithClass:[ActListViewController class]] view]
       setHidden:![_listViewControl isSelectedForSegment:0]];
      [[[self viewControllerWithClass:[ActNotesListViewController class]] view]
       setHidden:![_listViewControl isSelectedForSegment:1]];
    }
}

- (void)windowWillClose:(NSNotification *)note
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [self saveWindowState];

  [NSApp terminate:self];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
  return _undoManager;
}

// NSSplitViewDelegate methods

- (BOOL)splitView:(NSSplitView *)view canCollapseSubview:(NSView *)subview
{
  return NO;
}

- (BOOL)splitView:(NSSplitView *)view shouldCollapseSubview:(NSView *)subview
    forDoubleClickOnDividerAtIndex:(NSInteger)idx
{
  return YES;
}

- (CGFloat)splitView:(NSSplitView *)view constrainMinCoordinate:(CGFloat)p
    ofSubviewAt:(NSInteger)idx
{
  NSView *subview = [[view subviews] objectAtIndex:idx];
  CGFloat min_size = [(ActSplitView *)view minimumSizeOfSubview:subview];

  return p + min_size;
}

- (CGFloat)splitView:(NSSplitView *)view constrainMaxCoordinate:(CGFloat)p
    ofSubviewAt:(NSInteger)idx
{
  NSView *subview = [[view subviews] objectAtIndex:idx];
  CGFloat min_size = [(ActSplitView *)view minimumSizeOfSubview:subview];

  return p - min_size;
}

- (BOOL)splitView:(NSSplitView *)view
    shouldAdjustSizeOfSubview:(NSView *)subview
{
  if ([view isKindOfClass:[ActSplitView class]])
    return [(ActSplitView *)view shouldAdjustSizeOfSubview:subview];
  else
    return YES;
}

@end
