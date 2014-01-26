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

#import <UIKit/UIKit.h>

#import "act-activity.h"

@interface ActActivityViewController : UIViewController
{
  std::unique_ptr<act::activity> _activity;
  NSString *_activityGPSPath;
  NSString *_activityGPSRev;
  std::unique_ptr<act::activity::gps_data_reader> _activityGPSReader;

  IBOutlet UILabel *_courseLabel;
  IBOutlet UILabel *_activityLabel;
  IBOutlet UILabel *_dateLabel;
  IBOutlet UILabel *_timeLabel;

  IBOutlet UILabel *_distanceLabel;
  IBOutlet UILabel *_durationLabel;
  IBOutlet UILabel *_paceLabel;
  IBOutlet UILabel *_avgHRLabel;
  IBOutlet UILabel *_cadenceLabel;
  IBOutlet UILabel *_pointsLabel;

  IBOutlet NSLayoutConstraint *_distanceHeightConstraint;
  IBOutlet NSLayoutConstraint *_durationHeightConstraint;
  IBOutlet NSLayoutConstraint *_paceHeightConstraint;
  IBOutlet NSLayoutConstraint *_avgHRHeightConstraint;
  IBOutlet NSLayoutConstraint *_cadenceHeightConstraint;
  IBOutlet NSLayoutConstraint *_pointsHeightConstraint;

  IBOutlet NSLayoutConstraint *_separator1HeightConstraint;
  IBOutlet NSLayoutConstraint *_separator2HeightConstraint;

  IBOutlet UILabel *_notesLabel;
}

+ (ActActivityViewController *)instantiate;

@property(nonatomic) act::activity_storage_ref activityStorage;

@end
