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

@implementation ActActivityEditorViewController

@synthesize database = _database;

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
  [self dismissViewControllerAnimated:YES completion:nil];
}

/* UITableViewDataSource methods. */

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
  return 0;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec
{
  return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tv
    cellForRowAtIndexPath:(NSIndexPath *)path
{
  NSString *ident;
  UITableViewCell *cell;

  ident = @"XXX";

  if (ident == nil)
    return nil;

  cell = [tv dequeueReusableCellWithIdentifier:ident];

  if (cell == nil)
    {
      if ([ident isEqualToString:@"XXX"])
	{
	  cell = [[UITableViewCell alloc] initWithStyle:
		  UITableViewCellStyleDefault reuseIdentifier:ident];
	}
    }

  if ([ident isEqualToString:@"XXX"])
    {
    }

  return cell;
}

/* UITableViewDelegate methods. */

- (CGFloat)tableView:(UITableView *)tv
    heightForRowAtIndexPath:(NSIndexPath *)path
{
  return tv.rowHeight;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)path
{
#if 0
  UITableViewCell *cell = [tv cellForRowAtIndexPath:path];

  NSString *ident = cell.reuseIdentifier;

  if ([ident isEqualToString:@"XXX"])
    {
    }
#endif

  [tv deselectRowAtIndexPath:path animated:NO];
}

@end
