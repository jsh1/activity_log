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

#import "ActFieldEditorViewController.h"

#import "ActAppDelegate.h"
#import "ActTableViewStringEditorCell.h"

@implementation ActFieldEditorViewController
{
  act::field_data_type _type;
  NSString *_stringValue;

  NSString *_headerString;
  NSString *_footerString;

  ActTableViewEditorCell *_editorCell;
}

@synthesize type = _type;
@synthesize stringValue = _stringValue;
@synthesize optionStrings = _optionsStrings;
@synthesize headerString = _headerString;
@synthesize footerString = _footerString;

- (id)initWithFieldType:(act::field_data_type)type;
{
  self = [super initWithStyle:UITableViewStyleGrouped];
  if (self == nil)
    return nil;

  _type = type;

  return self;
}

- (void)invalidate
{
  self.tableView.dataSource = nil;
  self.tableView.delegate = nil;

  [_editorCell invalidate];

  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc
{
  [self invalidate];
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  UITableView *view = self.tableView;

  view.dataSource = self;
  view.delegate = self;
  view.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

  switch (_type)
    {
    case act::field_data_type::number:
    case act::field_data_type::date:
    case act::field_data_type::duration:
    case act::field_data_type::distance:
    case act::field_data_type::pace:
    case act::field_data_type::speed:
    case act::field_data_type::temperature:
    case act::field_data_type::fraction:
    case act::field_data_type::weight:
    case act::field_data_type::heart_rate:
    case act::field_data_type::cadence:
    case act::field_data_type::efficiency:
    case act::field_data_type::keywords:
      /* FIXME: implement all these. */

    case act::field_data_type::string:
      _editorCell = [ActTableViewStringEditorCell instantiate];
      break;
    }

  _editorCell.action = @selector(editorCellAction:);
  _editorCell.target = self;
}

- (void)viewWillAppear:(BOOL)animated
{
  _editorCell.stringValue = _stringValue;

  [_editorCell viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
  if ([_optionsStrings count] == 0)
    [_editorCell becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated
{
  _stringValue = _editorCell.stringValue;

  [_editorCell resignFirstResponder];
}

- (void)reloadData
{
  [self.tableView reloadData];
}

- (IBAction)editorCellAction:(id)sender
{
  [self.navigationController popViewControllerAnimated:YES];
}

/* UITableViewDataSource methods. */

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
  return 1 + (_optionsStrings != nil);
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec
{
  if (sec == 0)
    return 1;
  else if (sec == 1)
    return [_optionsStrings count];
  else
    return 0;
}

- (NSString *)tableView:(UITableView *)tv
    titleForHeaderInSection:(NSInteger)sec
{
  if (sec == 0)
    return _headerString;
  else if (sec == 1)
    return @"Options";
  else
    return nil;
}

- (NSString *)tableView:(UITableView *)tv
    titleForFooterInSection:(NSInteger)sec
{
  if (sec == 0)
    return _footerString;
  else
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tv
    cellForRowAtIndexPath:(NSIndexPath *)path
{
  NSString *ident = nil;

  switch (path.section)
    {
    case 0:
      if (path.row == 0)
	return _editorCell;
      break;

    case 1:
      ident = @"optionCell";
      break;
    }

  if (ident == nil)
    return nil;

  UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];

  if (cell == nil)
    {
      if ([ident isEqualToString:@"optionCell"])
	{
	  cell = [[UITableViewCell alloc] initWithStyle:
		  UITableViewCellStyleDefault reuseIdentifier:ident];
	}
    }

  if ([ident isEqualToString:@"optionCell"])
    {
      cell.textLabel.text = _optionsStrings[path.row];
    }

  return cell;
}

/* UITableViewDelegate methods. */

- (CGFloat)tableView:(UITableView *)tv
    heightForRowAtIndexPath:(NSIndexPath *)path
{
  if (path.section == 0 && path.row == 0)
    {
      CGSize size = [_editorCell intrinsicContentSize];
      if (size.height != UIViewNoIntrinsicMetric)
	return size.height;
    }

  return tv.rowHeight;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)path
{
  if (path.section == 1)
    {
      _editorCell.stringValue = _optionsStrings[path.row];

      [self.navigationController popViewControllerAnimated:YES];
    }

  [tv deselectRowAtIndexPath:path animated:NO];
}

@end
