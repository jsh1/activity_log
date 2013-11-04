// -*- c-style: gnu -*-

#import "ActViewerViewController.h"

#import "ActActivityViewController.h"
#import "ActListViewController.h"
#import "ActNotesListViewController.h"
#import "ActSplitView.h"
#import "ActWindowController.h"

@implementation ActViewerViewController

+ (NSString *)viewNibName
{
  return @"ActViewerView";
}

- (id)initWithController:(ActWindowController *)controller
{
  self = [super initWithController:controller];
  if (self == nil)
    return nil;

  if (ActViewController *obj
      = [[ActListViewController alloc] initWithController:_controller])
    {
      [self addSubviewController:obj];
    }

  if (ActViewController *obj
      = [[ActNotesListViewController alloc] initWithController:_controller])
    {
      [self addSubviewController:obj];
    }

  // FIXME: also some kind of multi-activity summary view

  if (ActViewController *obj
      = [[ActActivityViewController alloc] initWithController:_controller])
    {
      [self addSubviewController:obj];
      [obj release];
    }

  _listViewType = -1;

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:_controller];

  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [_controller addSplitView:_splitView identifier:@"Viewer"];
  [_splitView setIndexOfResizableSubview:1];

  for (ActViewController *controller in [self subviewControllers])
    {
      if ([controller isKindOfClass:[ActActivityViewController class]])
	{
	  [controller addToContainerView:_contentContainer];
	  [[controller view] setHidden:
	   [_controller selectedActivityStorage] ? NO : YES];
	}
      else
	[controller addToContainerView:_listContainer];
    }

  if (_listViewType < 0)
    [self setListViewType:0];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (NSView *)initialFirstResponder
{
  Class cls = (_listViewType == 0
	       ? [ActNotesListViewController class]
	       : [ActListViewController class]);

  return [[self viewControllerWithClass:cls] initialFirstResponder];
}

- (void)setListViewType:(NSInteger)type
{
  if (_listViewType != type)
    {
      NSWindow *window = [[self view] window];

      ActViewController *list = [self viewControllerWithClass:
				 [ActListViewController class]];
      ActViewController *notes = [self viewControllerWithClass:
				  [ActNotesListViewController class]];

      ActViewController *oldC = type == 0 ? list : notes;
      ActViewController *newC = type == 1 ? list : notes;

      NSResponder *first = [window firstResponder];

      BOOL firstResponder = ([first isKindOfClass:[NSView class]]
			     && [(NSView *)first isDescendantOf:[oldC view]]);

      [[newC view] setHidden:NO];
      [[oldC view] setHidden:YES];

      _listViewType = type;

      [window setInitialFirstResponder:[newC initialFirstResponder]];

      if (firstResponder)
	[window makeFirstResponder:[newC initialFirstResponder]];
    }
}

- (NSInteger)listViewType
{
  return _listViewType;
}

- (NSDictionary *)savedViewState
{
  NSMutableDictionary *state
    = [NSMutableDictionary dictionaryWithDictionary:[super savedViewState]];

  [state setObject:[NSNumber numberWithUnsignedInt:_listViewType]
   forKey:@"ActSelectedListView"];

  return state;
}

- (void)applySavedViewState:(NSDictionary *)state
{
  [super applySavedViewState:state];

  if (NSNumber *obj = [state objectForKey:@"ActSelectedListView"])
    {
      [self setListViewType:[obj intValue]];
    }
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  ActViewController *activityC = [self viewControllerWithClass:
				  [ActActivityViewController class]];

  [[activityC view] setHidden:
   [_controller selectedActivityStorage] ? NO : YES];
}

@end
