/* -*- c-style: gnu -*-

   Copyright (c) 2014 John Harper <jsh@unfactored.org>

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

#import "ActActivityEditorViewController.h"

#import "ActAppDelegate.h"
#import "ActColor.h"
#import "ActDatabaseManager.h"
#import "ActFieldEditorViewController.h"
#import "ActTextEditorViewController.h"

#import "act-activity.h"

#define BODY_ROW_HEIGHT 150

@interface ActActivityEditorViewController ()
@property(nonatomic, copy) void (^viewWillDisappearHandler)(void);
@end

@implementation ActActivityEditorViewController
{
  act::activity_storage_ref _activityStorage;

  /* Has a copy of _activityStorage, not the original. */

  std::unique_ptr<act::activity> _activity;
  BOOL _activityModified;
}

@synthesize viewWillDisappearHandler;

+ (ActActivityEditorViewController *)instantiate
{
  return [[[NSBundle mainBundle] loadNibNamed:
	   @"ActivityEditorView" owner:self options:nil] firstObject];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (act::activity_storage_ref)activityStorage
{
  return _activityStorage;
}

- (void)setActivityStorage:(act::activity_storage_ref)storage
{
  if (_activityStorage != storage)
    {
      _activityStorage = storage;

      /* making a copy in _activity so we can cancel if asked to. */

      act::activity_storage_ref copy(new act::activity_storage(*storage));

      _activity.reset(new act::activity(copy));

      [self reloadData];
    }
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  self.automaticallyAdjustsScrollViewInsets = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
  if (void (^handler)(void) = self.viewWillDisappearHandler)
    {
      self.viewWillDisappearHandler = nil;
      handler();
    }

  [self reloadData];
}

- (void)reloadData
{
  [self.tableView reloadData];
}

- (IBAction)doneAction:(id)sender
{
  if (_activityModified)
    {
      _activity->storage()->delete_empty_fields();
      *_activityStorage = *_activity->storage();

      [[ActDatabaseManager sharedManager] activityDidChange:_activityStorage];
    }

  [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)cancelAction:(id)sender
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

/* UITableViewDataSource methods. */

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
  return 4;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec
{
  if (sec == 0)
    return _activity->storage()->field_count();
  else
    return 1;
}

- (NSString *)tableView:(UITableView *)tv
    titleForHeaderInSection:(NSInteger)sec
{
  if (sec == 0)
    return @"Data Fields";
  else if (sec == 2)
    return @"Notes";
  else
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tv
    cellForRowAtIndexPath:(NSIndexPath *)path
{
  NSString *ident;
  UITableViewCell *cell;

  switch (path.section)
    {
    case 0:
      ident = @"fieldCell";
      break;
    case 1:
      ident = @"addFieldCell";
      break;
    case 2:
      ident = @"bodyCell";
      break;
    case 3:
      ident = @"deleteCell";
      break;
    default:
      return nil;
    }

  cell = [tv dequeueReusableCellWithIdentifier:ident];

  if (cell == nil)
    {
      if ([ident isEqualToString:@"fieldCell"])
	{
	  cell = [[UITableViewCell alloc] initWithStyle:
		  UITableViewCellStyleValue1 reuseIdentifier:ident];
	  cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
      else if ([ident isEqualToString:@"addFieldCell"])
	{
	  cell = [[UITableViewCell alloc] initWithStyle:
		  UITableViewCellStyleDefault reuseIdentifier:ident];
	  cell.textLabel.text = @"Add Field";
	  cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
      else if ([ident isEqualToString:@"bodyCell"])
	{
	  cell = [[UITableViewCell alloc] initWithStyle:
		  UITableViewCellStyleDefault reuseIdentifier:ident];
	  cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
      else if ([ident isEqualToString:@"deleteCell"])
	{
	  cell = [[UITableViewCell alloc] initWithStyle:
		  UITableViewCellStyleDefault reuseIdentifier:ident];
	  cell.textLabel.text = @"Delete Activity";
	  cell.textLabel.textColor = [tv tintColor];
	}
    }

  if ([ident isEqualToString:@"fieldCell"])
    {
      size_t idx = path.row;
      act::activity_storage_ref storage = _activity->storage();
      cell.textLabel.text = [NSString stringWithUTF8String:
			     storage->field_name(idx).c_str()];
      cell.detailTextLabel.text = [NSString stringWithUTF8String:
				   (*storage)[idx].c_str()];
    }
  else if ([ident isEqualToString:@"bodyCell"])
    {
      UILabel *label = cell.textLabel;
      label.lineBreakMode = NSLineBreakByWordWrapping;
      label.numberOfLines = 10;
      label.text = [[ActDatabaseManager sharedManager]
		    bodyStringOfActivity:*_activity];
      label.textColor = [UIColor colorWithWhite:.6 alpha:1];
    }
  
  return cell;
}

/* UITableViewDelegate methods. */

- (CGFloat)tableView:(UITableView *)tv
    heightForRowAtIndexPath:(NSIndexPath *)path
{
  if (path.section == 2)
    return BODY_ROW_HEIGHT;
  else
    return tv.rowHeight;
}

- (void)editFieldAtIndex:(size_t)idx
{
  auto field_id = act::lookup_field_id(_activity->field_name(idx).c_str());

  auto data_type = act::lookup_field_data_type(field_id);

  auto *controller = [[ActFieldEditorViewController alloc]
		      initWithFieldType:data_type];

  controller.stringValue
    = [NSString stringWithUTF8String:(*_activity)[idx].c_str()];

  controller.title = [NSString stringWithUTF8String:
		      _activity->field_name(idx).c_str()];

  /* FIXME: using this weak/strong dance to hide a compiler warning
     about a non-existent retain cycle (that I'm going to break by hand
     in -viewWillDisappear..) */

  __weak auto weak_self = self;

  self.viewWillDisappearHandler = ^
    {
      if (__strong auto strong_self = weak_self)
	{
	  act::activity &a = *strong_self->_activity;

	  std::string str([controller.stringValue UTF8String]);
	  canonicalize_field_string(controller.type, str);

	  a[idx] = str;
	  a.increment_seed();

	  strong_self->_activityModified = YES;
	}
    };

  [self.navigationController pushViewController:controller animated:YES];
}

- (void)addField
{
  auto *controller = [[ActFieldEditorViewController alloc]
		      initWithFieldType:act::field_data_type::string];

  controller.title = @"Field Name";

  controller.optionStrings = @[@"Activity", @"Type", @"Course",
    @"Duration", @"Distance", @"Pace", @"Equipment", @"Temperature",
    @"Weather", @"Weight", @"Keywords", @"Points", @"Effort", @"Quality",
    @"Resting-HR", @"Avg-HR", @"Max-HR", @"Avg-Cadence", @"Max-Cadence",
    @"Calories", @"Training-Effect"];

  __weak auto weak_self = self;

  self.viewWillDisappearHandler = ^
    {
      if (__strong auto strong_self = weak_self)
	{
	  act::activity &a = *strong_self->_activity;

	  NSString *str
	    = [controller.stringValue stringByTrimmingCharactersInSet
	       :[NSCharacterSet whitespaceCharacterSet]];

	  if ([str length] != 0)
	    {
	      const char *field_name = [str UTF8String];

	      auto field_id = act::lookup_field_id(field_name);
	      if (field_id != act::field_id::custom)
		field_name = act::canonical_field_name(field_id);

	      if (a.field_index(field_name) < 0)
		{
		  a[field_name] = "";
		  a.increment_seed();

		  strong_self->_activityModified = YES;
		}
	    }
	}
    };

  [self.navigationController pushViewController:controller animated:YES];
}

- (void)editBody
{
  auto *controller = [[ActTextEditorViewController alloc] init];

  controller.stringValue = [[ActDatabaseManager sharedManager]
			    bodyStringOfActivity:*_activity];

  controller.title = @"Notes";

  __weak auto weak_self = self;

  self.viewWillDisappearHandler = ^
    {
      if (__strong auto strong_self = weak_self)
	{
	  [[ActDatabaseManager sharedManager] setBodyString:
	   controller.stringValue ofActivity:*strong_self->_activity];

	  strong_self->_activityModified = YES;
	}
    };

  [self.navigationController pushViewController:controller animated:YES];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)path
{
  switch (path.section)
    {
    case 0:
      [self editFieldAtIndex:path.row];
      break;

    case 1:
      [self addField];
      break;

    case 2:
      [self editBody];
      break;

    case 3:
      /* FIXME: delete activity (somehow). */
      break;
    }

  [tv deselectRowAtIndexPath:path animated:NO];
}

@end
