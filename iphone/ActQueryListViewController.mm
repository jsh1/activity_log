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

#import "ActQueryListViewController.h"

@implementation ActQueryListViewController

@synthesize queryMode = _queryMode;
@synthesize queryYear = _queryYear;
@synthesize queryActivity = _queryActivity;

- (void)reloadData
{
  /* FIXME: use ActDatabaseManager to query and asynchronously update
     local store of what's visible. */
}

/* UITableViewDataSource methods. */

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
  switch (_queryMode)
    {
    case ActQueryListTopLevel:
      return 3;

    case ActQueryListYear:
    case ActQueryListActivity:
      return 2;

    default:
      return 0;
    }
}

- (NSString *)tableView:(UITableView *)tv
    titleForHeaderInSection:(NSInteger)sec
{
  if (sec == 0)
    return nil;

  if (_queryMode == ActQueryListTopLevel)
    return sec == 1 ? @"Activities" : @"Year";
  else if (_queryMode == ActQueryListYear)
    return @"Month";
  else if (_queryMode == ActQueryListActivity)
    return @"Activity Type";

  return nil;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec
{
  if (sec == 0)
    return 1;

  /* FIXME: implement this. */
  return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tv
    cellForRowAtIndexPath:(NSIndexPath *)path
{
  NSString *ident = @"queryCell";

  UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];

  if (cell == nil)
    {
      cell = [[UITableViewCell alloc] initWithStyle:
	      UITableViewCellStyleDefault reuseIdentifier:ident];
    }

  if (path.section == 0)
    [[cell textLabel] setText:@"All Activities"];

  /* FIXME: implement other sections. */

  return cell;
}

/* UITableViewDelegate methods. */

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)path
{
  /* FIXME: implement this. */
}

@end
