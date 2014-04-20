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

#import "ActActivityLapCell.h"

#import "ActColor.h"

#import "act-format.h"
#import "act-gps-activity.h"

#import "Macros.h"

@implementation ActActivityLapCell
{
  IBOutlet UILabel *_distanceLabel;
  IBOutlet UILabel *_paceLabel;
  IBOutlet UIView *_paceView;

  NSLayoutConstraint *_widthConstraint;

  const act::activity *_activity;
  NSInteger _lapIndex;
}

@synthesize activity = _activity;
@synthesize lapIndex = _lapIndex;

+ (NSString *)nibName
{
  return @"ActivityLapCell";
}

- (void)reloadData
{
  if (_activity == nullptr)
    return;

  const act::gps::activity *a = _activity->gps_data();
  if (!a)
    return;

  if (_lapIndex < 0 || _lapIndex >= a->laps().size())
    return;

  double distance = 0;
  for (size_t i = 0; i <= (size_t)_lapIndex; i++)
    distance += a->laps()[i].total_distance;

  std::string buf;

  act::format_distance(buf, distance, act::unit_type::unknown);
  _distanceLabel.text = [NSString stringWithUTF8String:buf.c_str()];
  buf.clear();

  float lap_speed = a->laps()[_lapIndex].avg_speed;

  act::format_pace(buf, lap_speed, act::unit_type::unknown);
  _paceLabel.text = [NSString stringWithUTF8String:buf.c_str()];
  buf.clear();

  float min_speed = HUGE_VALF;
  float max_speed = -HUGE_VALF;
  for (const auto &it : a->laps())
    {
      min_speed = std::min(min_speed, it.avg_speed);
      max_speed = std::max(max_speed, it.avg_speed);
    }

  float f = (max_speed - lap_speed) / (max_speed - min_speed) * .5f + .5f;

  if (_widthConstraint != nil)
    [_paceView.superview removeConstraint:_widthConstraint];

  _widthConstraint = [NSLayoutConstraint constraintWithItem:_paceView
		      attribute:NSLayoutAttributeWidth relatedBy:
		      NSLayoutRelationEqual toItem:_paceView.superview
		      attribute:NSLayoutAttributeWidth multiplier:f
		      constant:0];

  [_paceView.superview addConstraint:_widthConstraint];

  _paceView.layer.allowsEdgeAntialiasing = NO;
}

@end
