// -*- c-style: gnu -*-

#import "ActWindowController.h"

#import "ActActivityViewController.h"
#import "ActChartViewController.h"
#import "ActListViewController.h"
#import "ActNotesListViewController.h"
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
NSString *const ActCurrentTimeDidChange = @"ActCurrentTimeDidChange";
NSString *const ActActivityDidChangeField = @"ActActivityDidChangeField";
NSString *const ActActivityDidChangeBody = @"ActActivityDidChangeBody";

@interface ActWindowController ()
- (void)selectedActivityDidChange;
@end

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
      obj = [obj viewControllerWithClass:cls];
      if (obj != nil)
	return obj;
    }

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
  _currentTime = -1;

  return self;
}

- (void)windowDidLoad
{
  [self addSplitView:_outerSplitView identifier:@"Window.outerSplitView"];
  [self addSplitView:_innerSplitView identifier:@"Window.innerSplitView"];

  _fieldEditor = [[ActFieldEditor alloc] initWithFrame:NSZeroRect];
  [_fieldEditor setFieldEditor:YES];

  if (ActViewController *obj
      = [[ActListViewController alloc] initWithController:self])
    {
      [_viewControllers addObject:obj];
      [obj addToContainerView:_listContainer];
      [obj release];
    }

  if (ActViewController *obj
      = [[ActNotesListViewController alloc] initWithController:self])
    {
      [_viewControllers addObject:obj];
      [obj addToContainerView:_listContainer];
      [obj release];
    }

  if (ActViewController *obj
      = [[ActActivityViewController alloc] initWithController:self])
    {
      [_viewControllers addObject:obj];
      [obj addToContainerView:_contentContainer];
      [[obj view] setHidden:_selectedActivityStorage ? NO : YES];
      [obj release];
    }

  // FIXME: also some kind of multi-activity summary view

  _listViewType = -1;

  [self applySavedWindowState];

  if (_listViewType < 0)
    [self setListViewType:0];

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
  [view setDelegate:self];
  [_splitViews setObject:ident forKey:view];
}

- (void)removeSplitView:(ActSplitView *)view
{
  [_splitViews removeObjectForKey:view];
  [view setDelegate:nil];
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
			[NSNumber numberWithInt:_listViewType],
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
    {
      [self setListViewType:[obj intValue]];
    }
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

      [[NSNotificationCenter defaultCenter]
       postNotificationName:ActSelectedLapIndexDidChange object:self];
    }
}

- (double)currentTime
{
  return _currentTime;
}

- (void)setCurrentTime:(double)t
{
  if (_currentTime != t)
    {
      _currentTime = t;

      [[NSNotificationCenter defaultCenter]
       postNotificationName:ActCurrentTimeDidChange object:self];
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
  ActViewController *activityC = [self viewControllerWithClass:
				  [ActActivityViewController class]];

  [[activityC view] setHidden:_selectedActivityStorage ? NO : YES];

  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActSelectedActivityDidChange object:self];
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

- (void)setListViewType:(NSInteger)type
{
  if (_listViewType != type)
    {
      ActViewController *list = [self viewControllerWithClass:
				 [ActListViewController class]];
      ActViewController *notes = [self viewControllerWithClass:
				  [ActNotesListViewController class]];

      ActViewController *oldC = type == 1 ? list : notes;
      ActViewController *newC = type == 0 ? list : notes;

      NSResponder *first = [[self window] firstResponder];

      BOOL firstResponder = ([first isKindOfClass:[NSView class]]
			     && [(NSView *)first isDescendantOf:[oldC view]]);

      _listViewType = type;

      [[newC view] setHidden:NO];
      [[oldC view] setHidden:YES];

      [[self window] setInitialFirstResponder:[newC initialFirstResponder]];

      if (firstResponder)
	[[self window] makeFirstResponder:[newC initialFirstResponder]];
    }
}

- (NSInteger)listViewType
{
  return _listViewType;
}

- (IBAction)newActivity:(id)sender
{
  [self synchronizeIfNeeded];

  act::arguments args("act-new");
  args.push_back("--date");
  args.push_back("now");

  act::act_new(args);

  // FIXME: calling -reloadActivities immediately doesn't recognize the
  // new file for some reason.

  [self performSelector:@selector(reloadActivities)
   withObject:nil afterDelay:.25];
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

	 if ([urls count] != 0)
	   {
	     [[NSUserDefaults standardUserDefaults] setObject:
	      [[[urls lastObject] path] stringByDeletingLastPathComponent]
	      forKey:@"ActLastGPSImportDirectory"];
	   }

	 [self performSelector:@selector(reloadActivities)
	  withObject:nil afterDelay:.25];
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
  if (_selectedActivityStorage == nullptr)
    return [self firstActivity:sender];

  auto it = std::find(_activityList.begin(), _activityList.end(),
		      _selectedActivityStorage);

  if (++it < _activityList.end())
    [self setSelectedActivityStorage:*it];
  else
    NSBeep();
}

- (IBAction)previousActivity:(id)sender
{
  if (_selectedActivityStorage == nullptr)
    return [self lastActivity:sender];

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

- (IBAction)setListViewAction:(id)sender
{
  [self setListViewType:[sender tag]];
}

- (IBAction)toggleChartField:(id)sender
{
  ActChartViewController *controller
    = (id)[self viewControllerWithClass:[ActChartViewController class]];

  [controller toggleChartField:sender];
}

- (BOOL)chartFieldIsShown:(NSInteger)field
{
  ActChartViewController *controller
    = (id)[self viewControllerWithClass:[ActChartViewController class]];

  return [controller chartFieldIsShown:field];
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
