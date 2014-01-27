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

#import "ActActivityEditorViewController.h"
#import "ActAppDelegate.h"
#import "ActColor.h"
#import "ActDatabaseManager.h"
#import "ActFileManager.h"

#import "FoundationExtensions.h"

#import <time.h>
#import <xlocale.h>

@interface ActActivityViewController ()
- (void)reloadData;
- (void)updateConstraints;
@end

@implementation ActActivityViewController

@synthesize database = _database;

+ (ActActivityViewController *)instantiate
{
  return [[[NSBundle mainBundle] loadNibNamed:
	   @"ActivityView" owner:self options:nil] firstObject];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  ActFileManager *fm = [ActFileManager sharedManager];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(metadataCacheDidChange:)
   name:ActMetadataCacheDidChange object:fm];
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(fileCacheDidChange:)
   name:ActFileCacheDidChange object:fm];

  /* Make hairline separators. */

  CGFloat separator_height = 1 / [UIScreen mainScreen].scale;
  _separator1HeightConstraint.constant = separator_height;
  _separator2HeightConstraint.constant = separator_height;

  UIFont *font = [UIFont fontWithDescriptor:
		  [[UIFontDescriptor preferredFontDescriptorWithTextStyle:
		    UIFontTextStyleSubheadline]
		   fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold]
		  size:0];

  _distanceLabel.font = font;
  _durationLabel.font = font;
  _paceLabel.font = font;
  _avgHRLabel.font = font;
  _cadenceLabel.font = font;
  _pointsLabel.font = font;
}

- (void)viewWillAppear:(BOOL)flag
{
  [super viewWillAppear:flag];

  [self.navigationController setToolbarHidden:NO animated:flag];

  if (_activity)
    [self reloadData];
}

- (void)viewWillDisappear:(BOOL)flag
{
  [super viewWillDisappear:flag];

  [self.navigationController setToolbarHidden:YES animated:flag];
}

namespace {

struct gps_reader : public act::activity::gps_data_reader
{
  ActActivityViewController *_controller;

  gps_reader(ActActivityViewController *controller)
  : _controller(controller) {}

  virtual act::gps::activity *read_gps_file(const act::activity &a) const;
};

} // anonymous namespace

act::gps::activity *
gps_reader::read_gps_file(const act::activity &a) const
{
  if (_controller->_activity.get() != &a)
    return nullptr;

  NSString *path = _controller->_activityGPSPath;
  if (path == nil)
    return nullptr;

  ActFileManager *fm = [ActFileManager sharedManager];
  
  NSDictionary *meta = [fm metadataForRemotePath:
			[path stringByDeletingLastPathComponent]];
  if (meta == nil)
    return nullptr;

  NSString *file = [path lastPathComponent];

  for (NSDictionary *sub in meta[@"contents"])
    {
      NSString *name = sub[@"name"];
      if (![name isEqualToString:file caseInsensitive:YES])
	continue;

      NSString *rev = sub[@"rev"];
      NSString *local_path = [fm localPathForRemotePath:path revision:rev];

      if (local_path != nil)
	{
	  act::gps::activity *gps_data = new act::gps::activity;

	  if (gps_data->read_file([local_path fileSystemRepresentation]))
	    {
	      _controller->_activityGPSRev = rev;
	      return gps_data;
	    }

	  delete gps_data;
	}

      break;
    }

  return nullptr;
}

- (void)metadataCacheDidChange:(NSNotification *)note
{
  NSString *remote_path = [note userInfo][@"remotePath"];

  if ([[_activityGPSPath stringByDeletingLastPathComponent]
       isEqualToString:remote_path caseInsensitive:YES])
    {
      /* FIXME: check revision for our file. */

      _activity->invalidate_gps_data();
      _activityGPSRev = nil;

      [self reloadData];
    }
}

- (void)fileCacheDidChange:(NSNotification *)note
{
  NSString *remote_path = [note userInfo][@"remotePath"];

  if ([_activityGPSPath isEqualToString:remote_path caseInsensitive:YES])
    {
      _activity->invalidate_gps_data();
      _activityGPSRev = nil;

      [self reloadData];
    }
}

- (act::activity_storage_ref)activityStorage
{
  return _activity ? _activity->storage() : nullptr;
}

- (void)setActivityStorage:(act::activity_storage_ref)storage
{
  if (self.activityStorage != storage)
    {
      ActAppDelegate *delegate
	= (id)[UIApplication sharedApplication].delegate;

      _activity.reset(new act::activity(storage));

      _activityGPSPath = nil;
      if (const std::string *str = _activity->field_ptr("gps-file"))
	{
	  time_t date = _activity->date();
	  struct tm tm = {0};
	  localtime_r(&date, &tm);
	  char buf[128];
	  snprintf_l(buf, sizeof(buf), nullptr, "%d/%02d/",
		     tm.tm_year + 1900, tm.tm_mon + 1);

	  std::string tem(buf);
	  tem.append(*str);

	  _activityGPSPath = [delegate remoteGPSPath:
			      [NSString stringWithUTF8String:tem.c_str()]];
	}

      _activityGPSReader.reset(new gps_reader(self));
      _activity->set_gps_data_reader(_activityGPSReader.get());

      _activity->invalidate_gps_data();
      _activityGPSRev = nil;

      [self reloadData];
    }
}

- (void)reloadData
{
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

      _courseLabel.text = [_database stringForField:@"Course" ofActivity:*a];
      NSString *activity = [_database stringForField:@"Activity" ofActivity:*a];
      NSString *type = [_database stringForField:@"Type" ofActivity:*a];
      _activityLabel.text = [NSString stringWithFormat:@"%@, %@",
			     activity ? [activity capitalizedString] : @"",
			     type ? type : @""];
      NSDate *date = [NSDate dateWithTimeIntervalSince1970:(time_t)a->date()];
      _dateLabel.text = [NSString stringWithFormat:@"%@, %@",
			 [weekday_formatter stringFromDate:date],
			 [date_formatter stringFromDate:date]];
      _timeLabel.text = [@"at " stringByAppendingString:
			 [time_formatter stringFromDate:date]];
      _distanceLabel.text = [_database stringForField:@"Distance" ofActivity:*a];
      _durationLabel.text = [_database stringForField:@"Duration" ofActivity:*a];
      _paceLabel.text = [_database stringForField:@"Pace" ofActivity:*a];
      _avgHRLabel.text = [_database stringForField:@"Avg-HR" ofActivity:*a];
      _cadenceLabel.text = [_database stringForField:@"Avg-Cadence" ofActivity:*a];
      _pointsLabel.text = [_database stringForField:@"Points" ofActivity:*a];
      _notesLabel.text = [_database bodyStringOfActivity:*a];
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

- (IBAction)editAction:(id)sender
{
  ActActivityEditorViewController *controller
    = [ActActivityEditorViewController instantiate];

  controller.database = _database;
  controller.activityStorage = _activity->storage();

  UINavigationController *inner_nav
    = [[UINavigationController alloc] initWithRootViewController:controller];

  [self presentViewController:inner_nav animated:YES completion:nil];
}

@end
