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

#define BODY_ROW_HEIGHT 150

@implementation ActActivityEditorViewController

@synthesize database = _database;
@synthesize doneHandler = _doneHandler;

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

  if (_activityStorage != nullptr)
    [self reloadData];
}

- (void)reloadData
{
}

- (IBAction)doneAction:(id)sender
{
  if (_activityModified)
    {
      *_activityStorage = *_activity->storage();
      [_database activityDidChange:_activityStorage];
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
				   storage->field_value(idx).c_str()];
    }
  else if ([ident isEqualToString:@"bodyCell"])
    {
      UILabel *label = cell.textLabel;
      label.lineBreakMode = NSLineBreakByWordWrapping;
      label.numberOfLines = 10;
      label.text = [_database bodyStringOfActivity:*_activity];
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

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)path
{
  switch (path.section)
    {
    case 0:
      /* FIXME: edit this field. */
      break;

    case 1:
      /* FIXME: add new field. */
      break;

    case 2:
      /* FIXME: edit body text. */
      break;
    }

  [tv deselectRowAtIndexPath:path animated:NO];
}

@end
