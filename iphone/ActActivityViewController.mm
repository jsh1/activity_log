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

#import "ActActivityViewController.h"

#import "ActColor.h"
#import "ActDatabaseManager.h"

@interface ActActivityViewController ()
- (void)reloadData;
- (void)updateConstraints;
@end

@implementation ActActivityViewController

+ (ActActivityViewController *)instantiate
{
  return [[[NSBundle mainBundle] loadNibNamed:
	   @"ActivityView" owner:self options:nil] firstObject];
}

- (const act::activity_storage_ref)activityStorage
{
  return _activity ? _activity->storage() : nullptr;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  UIColor *red = [ActColor redTextColor];
  _distanceLabel.textColor = red;
  _durationLabel.textColor = red;
  _avgHRLabel.textColor = red;
  _cadenceLabel.textColor = red;
  _pointsLabel.textColor = red;

  /* Make hairline separators. */

  CGFloat separator_height = 1 / [UIScreen mainScreen].scale;
  _separator1HeightConstraint.constant = separator_height;
  _separator2HeightConstraint.constant = separator_height;
  _separator3HeightConstraint.constant = separator_height;

  if (_activity)
    [self reloadData];
}

- (void)viewWillAppear:(BOOL)flag
{
  UINavigationController *nav = (id)self.parentViewController;

  [nav setToolbarHidden:NO animated:flag];
}

- (void)viewWillDisappear:(BOOL)flag
{
  UINavigationController *nav = (id)self.parentViewController;

  [nav setToolbarHidden:YES animated:flag];
}

- (void)setActivityStorage:(const act::activity_storage_ref)storage
{
  if (self.activityStorage != storage)
    {
      _activity.reset(new act::activity(storage));

      [self reloadData];
    }
}

- (void)reloadData
{
  ActDatabaseManager *db = [ActDatabaseManager sharedManager];

  if (const act::activity *a = _activity.get())
    {
      static NSDateFormatter *date_formatter;
      static NSDateFormatter *time_formatter;
      static NSDateFormatter *weekday_formatter;

      if (date_formatter == nil)
	{
	  date_formatter = [[NSDateFormatter alloc] init];
	  [date_formatter setDateStyle:NSDateFormatterLongStyle];
	  [date_formatter setTimeStyle:NSDateFormatterNoStyle];
	  time_formatter = [[NSDateFormatter alloc] init];
	  [time_formatter setDateStyle:NSDateFormatterNoStyle];
	  [time_formatter setTimeStyle:NSDateFormatterShortStyle];
	  weekday_formatter = [[NSDateFormatter alloc] init];
	  [weekday_formatter setDateFormat:
	   [NSDateFormatter dateFormatFromTemplate:@"EEEE" options:0 locale:nil]];
	}

      _courseLabel.text = [db stringForField:@"Course" ofActivity:*a];
      NSString *activity = [db stringForField:@"Activity" ofActivity:*a];
      NSString *type = [db stringForField:@"Type" ofActivity:*a];
      _activityLabel.text = [NSString stringWithFormat:@"%@, %@",
			     activity ? [activity capitalizedString] : @"",
			     type ? type : @""];
      NSDate *date = [NSDate dateWithTimeIntervalSince1970:(time_t)a->date()];
      _dateLabel.text = [NSString stringWithFormat:@"%@, %@",
			 [weekday_formatter stringFromDate:date],
			 [date_formatter stringFromDate:date]];
      _timeLabel.text = [@"at " stringByAppendingString:
			 [time_formatter stringFromDate:date]];
      _distanceLabel.text = [db stringForField:@"Distance" ofActivity:*a];
      _durationLabel.text = [db stringForField:@"Duration" ofActivity:*a];
      _paceLabel.text = [db stringForField:@"Pace" ofActivity:*a];
      _avgHRLabel.text = [db stringForField:@"Avg-HR" ofActivity:*a];
      _cadenceLabel.text = [db stringForField:@"Avg-Cadence" ofActivity:*a];
      _pointsLabel.text = [db stringForField:@"Points" ofActivity:*a];
      _notesLabel.text = [db bodyStringOfActivity:*a];
    }
  else
    {
      _courseLabel.text = @"";
      _activityLabel.text = @"";
      _dateLabel.text = @"";
      _timeLabel.text = @"";
      _distanceLabel.text = @"";
      _durationLabel.text = @"";
      _paceLabel.text = @"";
      _avgHRLabel.text = @"";
      _cadenceLabel.text = @"";
      _pointsLabel.text = @"";
      _notesLabel.text = @"";
    }

  [self updateConstraints];
}

static inline void
update_constraint(NSLayoutConstraint *constraint, UILabel *label)
{
  const CGFloat spacing = 6;
  constraint.constant = [label.text length] == 0 ? 0 : spacing;
}

- (void)updateConstraints
{
  /* These constraints all are of the form:

	container.height = label.height * 1 + 8

     but if the label collapses to zero-height, we want to remove the
     8px spacing as well, so programmatically set the constraint's
     constant (the "+ 8") based on if the label is empty or not. */

  update_constraint(_distanceHeightConstraint, _distanceLabel);
  update_constraint(_durationHeightConstraint, _durationLabel);
  update_constraint(_paceHeightConstraint, _paceLabel);
  update_constraint(_avgHRHeightConstraint, _avgHRLabel);
  update_constraint(_cadenceHeightConstraint, _cadenceLabel);
  update_constraint(_pointsHeightConstraint, _pointsLabel);
}

@end
