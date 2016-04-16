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

#import "ActWindowController.h"

#import "ActActivityViewController.h"
#import "ActAppDelegate.h"
#import "ActDevice.h"
#import "ActDeviceManager.h"
#import "ActImporterViewController.h"
#import "ActPopoverViewController.h"
#import "ActSourceListItem.h"
#import "ActSourceListDeviceItem.h"
#import "ActSourceListQueryItem.h"
#import "ActSummaryViewController.h"
#import "ActViewerViewController.h"
#import "ActSplitView.h"
#import "ActTextField.h"

#import "FoundationExtensions.h"
#import "PXSourceList.h"

#import "act-config.h"
#import "act-format.h"
#import "act-new.h"
#import "act-util.h"

#import <map>
#import <set>

#define BODY_WRAP_COLUMN 72
#define SYNC_DELAY_NS (10LL*NSEC_PER_SEC)

enum ActSourceListSections
{
  ActSourceList_Devices,
  ActSourceList_Activities,
  ActSourceList_Date,
  ActSourceList_Queries,
  ActSourceListCount,
};

NSString *const ActActivityListDidChange = @"ActActivityListDidChange";
NSString *const ActSelectedActivityDidChange = @"ActSelectedActivityDidChange";
NSString *const ActSelectedLapIndexDidChange = @"ActSelectedLapIndexDidChange";
NSString *const ActCurrentTimeDidChange = @"ActCurrentTimeDidChange";
NSString *const ActCurrentTimeWillChange = @"ActCurrentTimeWillChange";
NSString *const ActActivityDidChangeField = @"ActActivityDidChangeField";
NSString *const ActActivityDidChangeBody = @"ActActivityDidChangeBody";
NSString *const ActSelectedDeviceDidChange = @"ActSelectedDeviceDidChange";

@interface ActWindowController ()
- (void)selectedActivityDidChange;
@end

namespace {

/* Extract space-, or doublequote-, delimited phrases into a vector of
   strings. Backslash can be used to escape individual characters. */

std::vector<std::string>
string_phrases(const char *str)
{
  std::vector<std::string> vec;

  static const char *separators[2] = {" \t\"\\", "\"\\"};

  while (str[0] != 0)
    {
      str += strspn(str, " \t");

      std::string token;
      bool finished_token = false;
      int in_quote = 0;

      while (!finished_token)
	{
	  size_t len = strcspn(str, separators[in_quote]);
	  token.append(str, len);
	  str += len;

	  switch (str[0])
	    {
	    case 0:
	      finished_token = true;
	      break;

	    case ' ':
	    case '\t':
	      len = strspn(str, " \t");
	      if (!in_quote)
		finished_token = true;
	      else
		token.append(str, len);
	      str += len;
	      break;

	    case '\\':
	      str++;
	      if (str[0] == 0)
		finished_token = true;
	      else
		token.push_back(*str++);
	      break;

	    case '"':
	      str++;
	      in_quote = !in_quote;
	      break;

	    default:
	      NSCAssert(false, @"string parser error");
	    }
	}

      if (token.size() != 0)
	vec.push_back(token);
    }
                   
  return vec;
}

/* Turn phrases into query terms. Either one of:

   FIELD:REGEXP  -- string match
   FIELD=VALUE   -- numeric comparison, = or one of !=, <=, >=, <, >
		    VALUE can contain unit spec.

   or just a string to match against the course field. */

act::database::const_query_term_ref
phrase_query_term(const char *pattern)
{
  const char *field = "course";

  size_t len = strcspn(pattern, " \t:=!<>");

  if (pattern[len] == ' ' || pattern[len] == '\t')
    {
      switch (pattern[len + strspn(pattern + len, " \t")])
	{
	case ':': case '=': case '!': case '<': case '>':
	  break;
	default:
	  len = strlen(pattern);
	}
    }

  if (pattern[len] == 0)
    {
      if (strcmp(field, "grep") == 0)
	return std::make_shared<act::database::grep_term>(pattern);
      else
	return std::make_shared<act::database::matches_term>(field, pattern);
    }

  // some kind of "FIELD\s+[:=!<>]\s+QUERY..." string

  char *tem = (char *)alloca(len + 1);
  memcpy(tem, pattern, len);
  tem[len] = 0;
  field = tem;
  pattern += len;

  pattern += strspn(pattern, " \t");

  if (pattern[0] == ':')
    {
      pattern += 1;
      pattern += strspn(pattern, " \t");
      if (strcmp(field, "grep") == 0)
	return std::make_shared<act::database::grep_term>(pattern);
      else
	return std::make_shared<act::database::matches_term>(field, pattern);
    }      

  auto op = act::database::compare_term::compare_op::equal;

  if (pattern[0] == '=')
    {
      op = act::database::compare_term::compare_op::equal;
      pattern += 1;
    }
  else if (pattern[0] == '!' && pattern[1] == '=')
    {
      op = act::database::compare_term::compare_op::not_equal;
      pattern += 2;
    }
  else if (pattern[0] == '<' && pattern[1] == '=')
    {
      op = act::database::compare_term::compare_op::less_or_equal;
      pattern += 2;
    }
  else if (pattern[0] == '>' && pattern[1] == '=')
    {
      op = act::database::compare_term::compare_op::greater_or_equal;
      pattern += 2;
    }
  else if (pattern[0] == '<')
    {
      op = act::database::compare_term::compare_op::less;
      pattern += 1;
    }
  else if (pattern[0] == '>')
    {
      op = act::database::compare_term::compare_op::greater;
      pattern += 1;
    }

  pattern += strspn(pattern, " \t");

  act::field_id id = act::lookup_field_id(field);
  act::field_data_type type = act::lookup_field_data_type(id);
  if (type == act::field_data_type::string)
    type = act::field_data_type::number;

  double rhs;
  if (!parse_value(std::string(pattern), type, &rhs, nullptr))
    return act::database::const_query_term_ref();

  return std::make_shared<act::database::compare_term>(field, op, rhs);
}

act::database::const_query_term_ref
append_string_query_terms(act::database::const_query_term_ref term,
			  const char *search_string)
{
  auto and_term = std::make_shared<act::database::and_term>();

  if (term)
    and_term->add_term(term);

  bool modified = false;

  for (const auto &str : string_phrases(search_string))
    {
      auto match_term = phrase_query_term(str.c_str());
      if (match_term)
	{
	  and_term->add_term(match_term);
	  modified = true;
	}
    }

  return modified ? and_term : term;
}

} // anonymous namespace

@implementation ActWindowController
{
  NSMutableArray *_sourceListItems;

  NSMutableArray *_viewControllers;
  NSMutableDictionary *_splitViews;

  NSInteger _windowMode;
  CGFloat _windowModeWidths[ActWindowMode_Count];

  std::unique_ptr<act::database> _database;
  BOOL _needsSynchronize;

  std::vector<act::database::item> _activityList;
  act::activity_storage_ref _selectedActivityStorage;
  std::unique_ptr<act::activity> _selectedActivity;
  NSInteger _selectedLapIndex;
  double _currentTime;

  ActDevice *_selectedDevice;

  NSPopover *_activityPopover;
}

@synthesize listTypeControl = _listTypeControl;
@synthesize reloadControl = _reloadControl;
@synthesize addControl = _addControl;
@synthesize importControl = _importControl;
@synthesize nextPreviousControl = _nextPreviousControl;
@synthesize splitView = _splitView;
@synthesize sourceListView = _sourceListView;
@synthesize contentContainer = _contentContainer;
@synthesize undoManager = _undoManager;
@synthesize fieldEditor = _fieldEditor;
@synthesize searchField = _searchField;
@synthesize searchMenu = _searchMenu;

- (NSString *)windowNibName
{
  return @"ActWindow";
}

- (ActViewController *)viewControllerWithClass:(Class)cls
{
  for (__strong ActViewController *obj in _viewControllers)
    {
      obj = [obj viewControllerWithClass:cls];
      if (obj != nil)
	return obj;
    }

  return nil;
}

- (ActSourceListItem *)sourceListItemWithPath:(NSString *)path
{
  NSArray *items = _sourceListItems;

  while (1)
    {
      NSString *rest = nil;

      NSRange range = [path rangeOfString:@"."];
      if (range.length != 0)
	{
	  rest = [path substringFromIndex:range.location+range.length];
	  path = [path substringToIndex:range.location];
	}

      BOOL found = NO;
      for (ActSourceListItem *item in items)
	{
	  if ([item.name isEqualToString:path])
	    {
	      if (rest == nil)
		return item;

	      found = YES;
	      items = item.subitems;
	      path = rest;
	      break;
	    }
	}
      if (!found)
	return nil;
    }

  // not reached
}

- (void)updateSourceList
{
  // devices are handled separate by -devicesDidChange:

  if (ActSourceListItem *item = [self sourceListItemWithPath:@"ACTIVITIES"])
    {
      item.subitems = @[];
      [item addSubitem:[ActSourceListQueryItem itemWithName:@"All"]];

      std::map<std::string, std::set<std::string>> map;

      for (const auto &it : self.database->items())
	{
	  if (const std::string *s = it.storage()->field_ptr("activity"))
	    {
	      std::set<std::string> &types = map[*s];
	      if (const std::string *ss = it.storage()->field_ptr("type"))
		types.insert(*ss);
	    }
	}

      for (const auto &it : map)
	{
	  act::database::query_term_ref type_term
	    (new act::database::equal_term("activity", it.first));

	  ActSourceListQueryItem *sub
	    = [ActSourceListQueryItem itemWithName:@(it.first.c_str())];
	  sub.query.set_term(type_term);
	  [item addSubitem:sub];

	  for (const auto &type : it.second)
	    {
	      act::database::query_term_ref subtype_term
		(new act::database::equal_term("type", type));
	      act::database::query_term_ref sub_term
		(new act::database::and_term(type_term, subtype_term));

	      ActSourceListQueryItem *sub2
	        = [ActSourceListQueryItem itemWithName:@(type.c_str())];
	      sub2.query.set_term(sub_term);
	      [sub addSubitem:sub2];
	      sub.expandable = YES;
	    }
	}

      [item foreachItem:^(ActSourceListItem *it) {
	 it.controller = self;
       }];

      [_sourceListView reloadItem:item reloadChildren:YES];
    }

  if (ActSourceListItem *item = [self sourceListItemWithPath:@"DATE"])
    {
      item.subitems = @[];

      const act::database *db = self.database;

      if (db->items().size() != 0)
	{
	  time_t start_date = db->items().back().date();
	  time_t end_date = db->items().front().date();

	  struct tm start_tm = {0};
	  localtime_r(&start_date, &start_tm);

	  struct tm end_tm = {0};
	  localtime_r(&end_date, &end_tm);

	  static NSDateFormatter *year_formatter, *month_formatter;

	  if (year_formatter == nil)
	    {
	      NSLocale *locale
	        = ((ActAppDelegate *)[NSApp delegate]).currentLocale;

	      year_formatter = [[NSDateFormatter alloc] init];
	      year_formatter.locale = locale;
	      year_formatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"yyyy"
		options:0 locale:locale];

	      month_formatter = [[NSDateFormatter alloc] init];
	      month_formatter.locale = locale;
	      month_formatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"MMMM"
		options:0 locale:locale];
	    }

	  auto it = db->items().cbegin();
	  const auto &it_end = db->items().cend();

	  int year = 1900 + end_tm.tm_year;
	  time_t year_max = act::year_time(year+1);

	  while (year - 1900 >= start_tm.tm_year)
	    {
	      time_t year_min = act::year_time(year);

	      if (it != it_end && it->date() >= year_min)
		{
		  ActSourceListQueryItem *year_item
		    = [ActSourceListQueryItem itemWithName:
		       [year_formatter stringFromDate:
			[NSDate dateWithTimeIntervalSince1970:
			 year_min + act::timezone_offset()]]];
		  year_item.expandable = YES;
		  act::date_range year_range(year_min, year_max - year_min);
		  year_item.query.add_date_range(year_range);
		  [item addSubitem:year_item];

		  int month = 11;
		  time_t month_max = year_max;

		  while (month >= 0)
		    {
		      time_t month_min = act::month_time(year, month);

		      if (it != it_end && it->date() >= month_min)
			{
			  ActSourceListQueryItem *month_item
			    = [ActSourceListQueryItem itemWithName:
			       [month_formatter stringFromDate:
				[NSDate dateWithTimeIntervalSince1970:
				 month_min + act::timezone_offset()]]];
			  month_item.expandable = YES;
			  act::date_range month_range(month_min,
						      month_max - month_min);
			  month_item.query.add_date_range(month_range);
			  [year_item addSubitem:month_item];

			  while (it != it_end && it->date() >= month_min)
			    it++;
			}

		      month--;
		      month_max = month_min;
		    }
		}

	      year--;
	      year_max = year_min;
	    }
	}

      [item foreachItem:^(ActSourceListItem *it) {
	it.controller = self;
      }];

      [_sourceListView reloadItem:item reloadChildren:YES];
    }

  if (ActSourceListItem *item = [self sourceListItemWithPath:@"QUERIES"])
    {
      item.subitems = @[];

      for (NSDictionary *dict in [[NSUserDefaults standardUserDefaults]
				  arrayForKey:@"ActSavedQueries"])
	{
	  NSString *name = dict[@"name"];
	  NSString *query = dict[@"query"];

	  act::database::const_query_term_ref term;
	  term = append_string_query_terms(term, query.UTF8String);

	  ActSourceListQueryItem *subitem
	    = [[ActSourceListQueryItem alloc] init];

	  subitem.name = name;
	  subitem.query.set_term(term);
	  subitem.controller = self;
	  subitem.editable = YES;

	  [item addSubitem:subitem];
	}
    }
}

- (id)init
{
  self = [super initWithWindow:nil];
  if (self == nil)
    return nil;

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(devicesDidChange:)
   name:ActDeviceManagerDevicesDidChange
   object:[ActDeviceManager sharedDeviceManager]];

  _sourceListItems = [[NSMutableArray alloc] init];
  _viewControllers = [[NSMutableArray alloc] init];
  _splitViews = [[NSMutableDictionary alloc] init];
  _undoManager = [[NSUndoManager alloc] init];

  _windowMode = ActWindowMode_Nil;
  _windowModeWidths[ActWindowMode_Nil] = 700;
  _windowModeWidths[ActWindowMode_Viewer] = 1200;
  _windowModeWidths[ActWindowMode_Importer] = 700;

  _selectedLapIndex = -1;
  _currentTime = -1;

  [_sourceListItems addObject:[ActSourceListItem itemWithName:@"DEVICES"]];
  [_sourceListItems addObject:[ActSourceListItem itemWithName:@"ACTIVITIES"]];
  [_sourceListItems addObject:[ActSourceListItem itemWithName:@"DATE"]];
  [_sourceListItems addObject:[ActSourceListItem itemWithName:@"QUERIES"]];

  for (ActSourceListItem *item in _sourceListItems)
    item.expandable = YES;

  [self updateSourceList];
  [self devicesDidChange:nil];

  return self;
}

- (void)windowDidLoad
{
  NSWindow *window = self.window;

  // 10.9 enables layer-backed views on the scrolling list view
  // implicitly, so we may as well enable them for the entire window.
  // Simple subview hierarchies that don't need multiple layers will
  // use inclusive (single-layer) mode (which also avoids any special
  // tricks being needed for font-smoothing).

  ((NSView *)window.contentView).wantsLayer = YES;

  [self addSplitView:_splitView identifier:@"0.Window"];
  _splitView.indexOfResizableSubview = 1;

  _fieldEditor = [[ActFieldEditor alloc] initWithFrame:NSZeroRect];

  _fieldEditor.fieldEditor = YES;
  _fieldEditor.richText = NO;
  _fieldEditor.importsGraphics = NO;
  _fieldEditor.usesFontPanel = NO;
  _fieldEditor.continuousSpellCheckingEnabled = NO;
  _fieldEditor.grammarCheckingEnabled = NO;
  _fieldEditor.allowsDocumentBackgroundColorChange = NO;
  _fieldEditor.allowsImageEditing = NO;

  if (ActViewController *obj = [[ActViewerViewController alloc]
				initWithController:self options:nil])
    {
      [_viewControllers addObject:obj];
    }

  if (ActViewController *obj = [[ActImporterViewController alloc]
				initWithController:self options:nil])
    {
      [_viewControllers addObject:obj];
    }

  if (ActViewController *obj = [[ActPopoverViewController alloc]
				initWithController:self options:nil])
    {
      [_viewControllers addObject:obj];
    }

  // make sure we're in viewer mode before trying to restore view state

  self.windowMode = ActWindowMode_Viewer;

  [self applySavedWindowState];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(windowWillClose:)
   name:NSWindowWillCloseNotification object:window];

  for (ActSourceListItem *item in _sourceListItems)
    [_sourceListView expandItem:item];

  [_sourceListView selectRowIndexes:
   [NSIndexSet indexSetWithIndex:
    [_sourceListView rowForItem:
     [self sourceListItemWithPath:@"ACTIVITIES.All"]]]
   byExtendingSelection:NO];

  window.initialFirstResponder = [self viewControllerWithClass:
   [ActViewerViewController class]].initialFirstResponder;

  _listTypeControl.selectedSegment = ((ActViewerViewController *)
    [self viewControllerWithClass:[ActViewerViewController class]])
    .listViewType;

  [self updateUnimportedActivitiesCount];

  [window makeFirstResponder:window.initialFirstResponder];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [NSRunLoop cancelPreviousPerformRequestsWithTarget:self];

  [_activityPopover close];

}

- (void)setSavedQueries:(NSArray *)queries reload:(BOOL)flag
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  [[_undoManager prepareWithInvocationTarget:self]
   setSavedQueries:[defaults arrayForKey:@"ActSavedQueries"]
   reload:YES];

  [defaults setObject:queries forKey:@"ActSavedQueries"];

  if (flag)
    {
      [self updateSourceList];
      [_sourceListView reloadData];
    }
}

- (void)addSplitView:(ActSplitView *)view identifier:(NSString *)ident
{
  view.delegate = self;
  _splitViews[ident] = view;
}

- (void)removeSplitView:(ActSplitView *)view identifier:(NSString *)ident
{
  [_splitViews removeObjectForKey:ident];
  view.delegate = nil;
}

- (void)saveWindowState
{
  if (!self.windowLoaded || self.window == nil)
    return;

  NSMutableDictionary *controllers = [NSMutableDictionary dictionary];

  for (ActViewController *controller in _viewControllers)
    {
      NSDictionary *sub = [controller savedViewState];
      if (sub.count != 0)
	controllers[controller.identifier] = sub;
    }

  NSMutableDictionary *split = [NSMutableDictionary dictionary];

  for (NSString *ident in _splitViews)
    {
      ActSplitView *view = _splitViews[ident];
      NSDictionary *sub = [view savedViewState];
      if (sub.count != 0)
	split[ident] = sub;
    }

  NSDictionary *dict = @{
    @"ActViewControllers": controllers,
    @"ActSplitViews": split,
  };

  [[NSUserDefaults standardUserDefaults]
   setObject:dict forKey:@"ActSavedWindowState"];
}

- (void)applySavedWindowState
{
  NSDictionary *state = [[NSUserDefaults standardUserDefaults]
			 dictionaryForKey:@"ActSavedWindowState"];
  if (state == nil)
    return;

  if (NSDictionary *dict = state[@"ActViewControllers"])
    {
      for (ActViewController *controller in _viewControllers)
	{
	  if (NSDictionary *sub = dict[controller.identifier])
	    [controller applySavedViewState:sub];
	}
    }

  if (NSDictionary *dict = state[@"ActSplitViews"])
    {
      NSArray *split_keys = [_splitViews.allKeys sortedArrayUsingSelector:
			     @selector(caseInsensitiveCompare:)];

      for (NSString *ident in split_keys)
	{
	  ActSplitView *view = _splitViews[ident];
	  if (NSDictionary *sub = dict[ident])
	    [view applySavedViewState:sub];
	}
    }
}

- (NSInteger)windowMode
{
  return _windowMode;
}

- (void)setWindowMode:(NSInteger)mode
{
  if (_windowMode != mode)
    {
      Class old_class = nil;
      if (_windowMode == ActWindowMode_Viewer)
	old_class = [ActViewerViewController class];
      else if (_windowMode == ActWindowMode_Importer)
	old_class = [ActImporterViewController class];

      if (old_class != nil)
	{
	  ActViewController *controller
	    = [self viewControllerWithClass:old_class];
	  [controller removeFromContainer];
	}

      NSRect frame = self.window.frame;
      _windowModeWidths[_windowMode] = frame.size.width;

      _windowMode = mode;

#if 0
      frame.size.width = _windowModeWidths[_windowMode];
      self.window.frame = frame;
#endif

      Class new_class = nil;
      if (_windowMode == ActWindowMode_Viewer)
	new_class = [ActViewerViewController class];
      else if (_windowMode == ActWindowMode_Importer)
	new_class = [ActImporterViewController class];

      if (new_class != nil)
	{
	  ActViewController *controller
	    = [self viewControllerWithClass:new_class];
	  [controller addToContainerView:_contentContainer];
	}
    }
}

- (NSInteger)listViewType
{
  return ((ActViewerViewController *)[self viewControllerWithClass:
   [ActViewerViewController class]]).listViewType;
}

- (void)setListViewType:(NSInteger)x
{
  ((ActViewerViewController *)[self viewControllerWithClass:
    [ActViewerViewController class]]).listViewType = x;

  _listTypeControl.selectedSegment = x;
}

- (IBAction)listViewAction:(id)sender
{
  if (sender == _listTypeControl) {
    self.listViewType = _listTypeControl.selectedSegment;
  }
}

- (act::database *)database
{
  if (!_database)
    {
      _database.reset (new act::database());
      _database->reload();
    }

  return _database.get();
}

- (void)showQueryResults:(const act::database::query &)query
{
  _activityList.clear();

  NSString *pattern = _searchField.stringValue;

  if (pattern.length == 0)
    self.database->execute_query(query, _activityList);
  else
    {
      act::database::query pattern_query(query);
      pattern_query.set_term(append_string_query_terms
			     (query.term(), pattern.UTF8String));
      self.database->execute_query(pattern_query, _activityList);
    }

  BOOL selection = NO;
  for (auto &it : _activityList)
    {
      if (it.storage() == _selectedActivityStorage)
	{
	  selection = YES;
	  break;
	}
    }

  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActActivityListDidChange object:self];

  if (!selection)
    self.selectedActivityStorage = _activityList.size() > 0 ? _activityList[0].storage() : nullptr;
}

- (void)reloadActivities
{
  self.selectedActivityStorage = nullptr;

  self.database->reload();

  [self sourceListSelectionDidChange:nil];

  [_sourceListView reloadData];

  [self updateUnimportedActivitiesCount];
}

- (const std::vector<act::database::item> &)activityList
{
  return _activityList;
}

- (void)setActivityList:(const std::vector<act::database::item> &)vec
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
      [[NSNotificationCenter defaultCenter]
       postNotificationName:ActCurrentTimeWillChange object:self];

      _currentTime = t;

      [[NSNotificationCenter defaultCenter]
       postNotificationName:ActCurrentTimeDidChange object:self];
    }
}

- (ActDevice *)selectedDevice
{
  return _selectedDevice;
}

- (void)setSelectedDevice:(ActDevice *)device
{
  if (_selectedDevice != device)
    {
      _selectedDevice = device;

      [[NSNotificationCenter defaultCenter]
       postNotificationName:ActSelectedDeviceDidChange object:self];
    }
}

- (void)setNeedsSynchronize:(BOOL)flag
{
  if (flag && !_needsSynchronize)
    {
      _needsSynchronize = YES;

      dispatch_time_t t = dispatch_time(DISPATCH_TIME_NOW, SYNC_DELAY_NS);
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

- (void)activity:(const act::activity_storage_ref)a
    didChangeField:(NSString *)name;
{
  self.needsSynchronize = YES;

  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActActivityDidChangeField object:self
   userInfo:@{@"activity": [NSValue valueWithPointer:&a], @"field": name}];
}

- (void)activityDidChangeBody:(const act::activity_storage_ref)a
{
  self.needsSynchronize = YES;

  [[NSNotificationCenter defaultCenter]
   postNotificationName:ActActivityDidChangeBody object:self
   userInfo:@{@"activity": [NSValue valueWithPointer:&a]}];
}

- (NSString *)bodyString
{
  if (const act::activity *a = self.selectedActivity)
    return [self bodyStringOfActivity:*a];
  else
    return @"";
}

- (void)setBodyString:(NSString *)str
{
  if (act::activity *a = self.selectedActivity)
    [self setBodyString:str ofActivity:*a];
}

- (NSDate *)dateField
{
  if (const act::activity *a = self.selectedActivity)
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
      act::format_date_time(str, (time_t) date.timeIntervalSince1970);
      value = @(str.c_str());
    }

  [self setString:value forField:@"Date"];
}

- (NSString *)stringForField:(NSString *)name
{
  if (const act::activity *a = self.selectedActivity)
    return [self stringForField:name ofActivity:*a];
  else
    return nil;
}

- (NSString *)stringForField:(NSString *)name
    ofActivity:(const act::activity &)a
{
  const char *field = name.UTF8String;
  act::field_id field_id = act::lookup_field_id(field);
  act::field_data_type field_type = act::lookup_field_data_type(field_id);

  std::string ret;

  switch (field_type)
    {
    case act::field_data_type::string:
      if (const std::string *s = a.field_ptr(field))
	return @(s->c_str());
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

  return @(ret.c_str());
}

- (BOOL)isFieldReadOnly:(NSString *)name
{
  if (const act::activity *a = self.selectedActivity)
    return [self isFieldReadOnly:name ofActivity:*a];
  else
    return YES;
}

- (BOOL)isFieldReadOnly:(NSString *)name ofActivity:(const act::activity &)a
{
  return a.storage()->field_read_only_p(name.UTF8String);
}

- (void)setString:(NSString *)str forField:(NSString *)name
{
  if (act::activity *a = self.selectedActivity)
    [self setString:str forField:name ofActivity:*a];
}

- (void)setString:(NSString *)str forField:(NSString *)name
    ofActivity:(act::activity &)a
{
  const char *field_name = name.UTF8String;
  auto id = act::lookup_field_id(field_name);
  if (id != act::field_id::custom)
    field_name = act::canonical_field_name(id);

  // FIXME: trim whitespace?

  if (str.length != 0)
    {
      auto type = act::lookup_field_data_type(id);

      std::string value(str.UTF8String);
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
  if (act::activity *a = self.selectedActivity)
    [self deleteField:name ofActivity:*a];
}

- (void)deleteField:(NSString *)name ofActivity:(act::activity &)a
{
  [self setString:nil forField:name ofActivity:a];
}

- (void)renameField:(NSString *)oldName to:(NSString *)newName
{
  if (act::activity *a = self.selectedActivity)
    [self renameField:oldName to:newName ofActivity:*a];
}

- (void)renameField:(NSString *)oldName to:(NSString *)newName
    ofActivity:(act::activity &)a
{
  if (newName.length == 0)
    return [self deleteField:newName ofActivity:a];

  a.storage()->set_field_name(oldName.UTF8String, newName.UTF8String);

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
	}

      return str;
    }

  return @"";
}

- (void)setBodyString:(NSString *)str ofActivity:(act::activity &)a
{
  static const char whitespace[] = " \t\n\f\r";

  const char *ptr = str.UTF8String;
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
	default_dir = @(path);
    }

  panel.allowedFileTypes = @[@"fit", @"tcx"];
  panel.allowsMultipleSelection = YES;
  panel.directoryURL = [NSURL fileURLWithPath:default_dir];
  panel.prompt = @"Import";
  panel.title = @"Select FIT/TCX Files to Import";

  [panel beginWithCompletionHandler:^(NSInteger status) {
    if (status == NSFileHandlingPanelOKButton)
      {
	NSArray *urls = panel.URLs;

	for (NSURL *url in urls)
	  {
	    if (!url.fileURL)
	      continue;

	    act::arguments args("act-new");
	    args.push_back("--gps-file");
	    args.push_back(url.path.UTF8String);

	    act::act_new(args);
	  }

	if (urls.count != 0)
	  {
	    [[NSUserDefaults standardUserDefaults] setObject:
	     [urls.lastObject path].stringByDeletingLastPathComponent
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

- (void)foreachUnimportedActivityURL:(void (^)(NSURL *url))block
{
  for (ActDevice *device in [ActDeviceManager sharedDeviceManager].allDevices)
    {
      for (NSURL *url in device.activityURLs)
	{
	  @autoreleasepool
	    {
	      const char *path = url.path.lastPathComponent.UTF8String;
	      act::database::query_term_ref term
		(new act::database::equal_term("gps-file", path));

	      act::database::query q;
	      q.set_term(term);

	      std::vector<act::database::item> results;
	      _database->execute_query(q, results);

	      if (results.size() == 0)
		block(url);
	    }
	}
    }
}

- (void)updateUnimportedActivitiesCount
{
  __block NSInteger count = 0;

  [self foreachUnimportedActivityURL:^(NSURL *url) {
    count++;
  }];

  NSString *title = count == 0 ? @"⬇︎" : [NSString stringWithFormat:@"⬇︎ %d", (int)count];
  [_importControl setLabel:title forSegment:0];
  _importControl.enabled = count != 0;
}

- (IBAction)importAllActivities:(id)sender
{
  ActImporterViewController *importer
    = (id)[self viewControllerWithClass:[ActImporterViewController class]];

  [self foreachUnimportedActivityURL:^(NSURL *url) {
    [importer importActivityFromURL:url];
  }];

  [importer reloadData];

  [self performSelector:@selector(reloadActivities)
   withObject:nil afterDelay:.25];
}

- (IBAction)editActivity:(id)sender
{
  self.windowMode = ActWindowMode_Viewer;

  [self.window makeFirstResponder:[self viewControllerWithClass:
    [ActSummaryViewController class]].initialFirstResponder];
}

- (IBAction)nextActivity:(id)sender
{
  self.windowMode = ActWindowMode_Viewer;

  if (_selectedActivityStorage == nullptr)
    return [self firstActivity:sender];

  auto it = std::find_if(_activityList.begin(), _activityList.end(),
			 [=] (const act::database::item &a) {
			   return a.storage() == _selectedActivityStorage;
			 });

  if (++it < _activityList.end())
    self.selectedActivityStorage = it->storage();
  else
    NSBeep();
}

- (IBAction)previousActivity:(id)sender
{
  self.windowMode = ActWindowMode_Viewer;

  if (_selectedActivityStorage == nullptr)
    return [self lastActivity:sender];

  auto it = std::find_if(_activityList.begin(), _activityList.end(),
			 [=] (const act::database::item &a) {
			   return a.storage() == _selectedActivityStorage;
			 });

  if (--it >= _activityList.begin())
    self.selectedActivityStorage = it->storage();
  else
    NSBeep();
}

- (IBAction)firstActivity:(id)sender
{
  self.windowMode = ActWindowMode_Viewer;

  if (_activityList.size() > 0)
    self.selectedActivityStorage = _activityList.front().storage();
}

- (IBAction)lastActivity:(id)sender
{
  self.windowMode = ActWindowMode_Viewer;

  if (_activityList.size() > 0)
    self.selectedActivityStorage = _activityList.back().storage();
}

- (IBAction)nextPreviousActivity:(id)sender
{
  if ([_nextPreviousControl.cell
       tagForSegment:_nextPreviousControl.selectedSegment] < 0)
    [self previousActivity:sender];
  else
    [self nextActivity:sender];
}

- (IBAction)searchAction:(id)sender
{
  [self sourceListSelectionDidChange:nil];
}

- (IBAction)saveSearchAction:(id)sender
{
  NSString *str = _searchField.stringValue;

  if (str.length == 0)
    {
      NSBeep();
      return;
    }

  NSMutableArray *queries = [NSMutableArray arrayWithArray:
			     [[NSUserDefaults standardUserDefaults]
			      arrayForKey:@"ActSavedQueries"]];

  [queries addObject:@{@"name": str, @"query": str}];

  [self setSavedQueries:queries reload:YES];
}

- (IBAction)performFindPanelAction:(id)sender
{
  [self.window makeFirstResponder:_searchField];
}

- (IBAction)setListViewAction:(id)sender
{
  self.windowMode = ActWindowMode_Viewer;
  self.listViewType = [sender tag];
}

- (IBAction)toggleActivityPane:(id)sender
{
  [[self viewControllerWithClass:[ActActivityViewController class]]
   performVoidSelector:_cmd withObject:sender];
}

- (void)showPopoverWithActivityStorage:(act::activity_storage_ref)storage
    relativeToRect:(NSRect)r ofView:(NSView *)view
    preferredEdge:(NSRectEdge)edge
{
  ActPopoverViewController *c = (ActPopoverViewController *)
    [self viewControllerWithClass:[ActPopoverViewController class]];

  if (_activityPopover == nil)
    {
      _activityPopover = [[NSPopover alloc] init];
      _activityPopover.contentViewController = c;
      _activityPopover.delegate = self;
    }

  NSView *c_view = c.view;
  c.activityStorage = storage;
  [c sizeToFit];
  _activityPopover.contentSize = c_view.frame.size;
  [_activityPopover showRelativeToRect:r ofView:view preferredEdge:edge];
}

- (void)hidePopover
{
  [_activityPopover close];
}

- (void)devicesDidChange:(NSNotification *)note
{
  ActSourceListItem *item = [self sourceListItemWithPath:@"DEVICES"];

  item.subitems = @[];

  for (ActDevice *device in [ActDeviceManager sharedDeviceManager].allDevices)
    [item addSubitem:[ActSourceListDeviceItem itemWithDevice:device]];

  [item foreachItem:^(ActSourceListItem *it) {
    it.controller = self;
  }];

  [_sourceListView reloadItem:item reloadChildren:YES];

  [self updateUnimportedActivitiesCount];
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

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item
{
  SEL sel = item.action;

  if (sel == @selector(importAllActivities:))
    {
      return _importControl.enabled;
    }

  if (sel == @selector(saveSearchAction:))
    {
      return _searchField.stringValue.length != 0;
    }

  return YES;
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
  NSView *subview = view.subviews[idx];
  CGFloat min_size = [(ActSplitView *)view minimumSizeOfSubview:subview];

  return p + min_size;
}

- (CGFloat)splitView:(NSSplitView *)view constrainMaxCoordinate:(CGFloat)p
    ofSubviewAt:(NSInteger)idx
{
  NSView *subview = view.subviews[idx];
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

// NSPopoverDelegate methods

- (void)popoverWillShow:(NSNotification *)notification
{
  [(ActViewController *)((NSPopover *)notification.object).contentViewController viewWillAppear];
}

- (void)popoverDidShow:(NSNotification *)notification
{
  [(ActViewController *)((NSPopover *)notification.object).contentViewController viewDidAppear];
}

- (void)popoverWillClose:(NSNotification *)notification
{
  [(ActViewController *)((NSPopover *)notification.object).contentViewController viewWillDisappear];
}

- (void)popoverDidClose:(NSNotification *)notification
{
  [(ActViewController *)((NSPopover *)notification.object).contentViewController viewDidDisappear];
}

// PXSourceListDataSource methods

- (NSUInteger)sourceList:(PXSourceList *)lst numberOfChildrenOfItem:(id)item
{
  if (item == nil)
    return _sourceListItems.count;
  else
    return ((ActSourceListItem *)item).subitemsCount;
}

- (id)sourceList:(PXSourceList *)lst child:(NSUInteger)idx ofItem:(id)item
{
  if (item == nil)
    return _sourceListItems[idx];
  else
    return ((ActSourceListItem *)item).subitems[idx];
}

- (id)sourceList:(PXSourceList *)lst objectValueForItem:(id)item
{
  return ((ActSourceListItem *)item).name;
}

- (void)sourceList:(PXSourceList*)lst setObjectValue:(id)value
  forItem:(id)item_
{
  ActSourceListItem *item = item_;

  NSArray *subitems = [self sourceListItemWithPath:@"QUERIES"].subitems;
  NSInteger idx = [subitems indexOfObjectIdenticalTo:item];

  if (idx != NSNotFound)
    {
      NSMutableArray *queries = [NSMutableArray arrayWithArray:
				 [[NSUserDefaults standardUserDefaults]
				  arrayForKey:@"ActSavedQueries"]];
      NSMutableDictionary *dict = [queries[idx] mutableCopy];
      dict[@"name"] = value;
      queries[idx] = dict;
      [self setSavedQueries:queries reload:NO];
      ((ActSourceListQueryItem *)item).name = value;
    }
}

- (BOOL)sourceList:(PXSourceList *)lst isItemExpandable:(id)item
{
  return ((ActSourceListItem *)item).expandable;
}

- (BOOL)sourceList:(PXSourceList *)lst itemHasBadge:(id)item
{
  return ((ActSourceListItem *)item).hasBadge;
}

- (NSInteger)sourceList:(PXSourceList *)lst badgeValueForItem:(id)item
{
  return ((ActSourceListItem *)item).badgeValue;
}

- (BOOL)sourceList:(PXSourceList *)lst itemHasIcon:(id)item
{
  return ((ActSourceListItem *)item).hasIcon;
}

- (NSImage*)sourceList:(PXSourceList *)lst iconForItem:(id)item
{
  return ((ActSourceListItem *)item).iconImage;
}

// PXSourceListDelegate methods

- (CGFloat)sourceList:(PXSourceList *)lst heightOfRowByItem:(id)item
{
  return 24;
}

- (BOOL)sourceList:(PXSourceList *)lst shouldEditItem:(id)item
{
  return ((ActSourceListItem *)item).editable;
}

- (void)sourceListSelectionDidChange:(NSNotification *)note
{
  ActSourceListItem *item = [_sourceListView itemAtRow:
			     _sourceListView.selectedRow];

  [item select];
}

- (void)sourceListDeleteKeyPressedOnRows:(NSNotification *)note
{
  NSIndexSet *rows = note.userInfo[@"rows"];

  NSArray *subitems = [self sourceListItemWithPath:@"QUERIES"].subitems;
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableArray *queries = [NSMutableArray arrayWithArray:
			     [defaults arrayForKey:@"ActSavedQueries"]];
  bool changed = false;

  for (NSInteger row = rows.lastIndex; row != NSNotFound;
       row = [rows indexLessThanIndex:row])
    {
      ActSourceListItem *item = [_sourceListView itemAtRow:row];
      NSInteger idx = [subitems indexOfObjectIdenticalTo:item];

      if (idx != NSNotFound)
	{
	  [queries removeObjectAtIndex:idx];
	  changed = true;
	}
    }

  if (changed)
    [self setSavedQueries:queries reload:YES];
}

@end
