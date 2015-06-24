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

#import "ActActivityChartItemView.h"

#import "ActActivityChartListViewController.h"

#import "act-gps-activity.h"
#import "act-gps-chart.h"

#import "Macros.h"

@implementation ActActivityChartItemView
{
  const act::activity *_activity;
  int _chartType;
  int _smoothing;
}

@synthesize controller = _controller;
@synthesize activity = _activity;
@synthesize chartType = _chartType;

- (void)reloadData
{
  [self setNeedsDisplay];
}

struct chart_values_t
{
  act::gps::activity::point_field field;
  act::gps::chart::value_conversion conversion;
  act::gps::chart::line_color color;
};

static chart_values_t chart_values[] =
{
  [ActActivityChartSpeed] =
    {
      act::gps::activity::point_field::speed,
      act::gps::chart::value_conversion::speed_ms_pace_mi,
      act::gps::chart::line_color::blue,
    },
  [ActActivityChartHeartRate] = 
    {
      act::gps::activity::point_field::heart_rate,
      act::gps::chart::value_conversion::identity,
      act::gps::chart::line_color::orange,
    },
  [ActActivityChartAltitude] = 
    {
      act::gps::activity::point_field::altitude,
      act::gps::chart::value_conversion::distance_m_ft,
      act::gps::chart::line_color::green,
    },
  [ActActivityChartCadence] = 
    {
      act::gps::activity::point_field::cadence,
      act::gps::chart::value_conversion::identity,
      act::gps::chart::line_color::tomato,
    },
  [ActActivityChartStrideLength] = 
    {
      act::gps::activity::point_field::stride_length,
      act::gps::chart::value_conversion::identity,
      act::gps::chart::line_color::dark_orchid,
    },
  [ActActivityChartVerticalOscillation] = 
    {
      act::gps::activity::point_field::vertical_oscillation,
      act::gps::chart::value_conversion::identity,
      act::gps::chart::line_color::teal,
    },
  [ActActivityChartStanceTime] = 
    {
      act::gps::activity::point_field::stance_time,
      act::gps::chart::value_conversion::identity,
      act::gps::chart::line_color::steel_blue,
    },
};

- (void)drawRect:(CGRect)clip
{
  const act::gps::activity *data = self.controller.smoothedData;
  if (data == nullptr)
    return;

  using namespace act::gps;

  if (_chartType < 0 || _chartType >= N_ELEMENTS(chart_values))
    return;

  act::gps::chart chart(*data, chart::x_axis_type::distance);

  uint32_t flags = chart::TICK_LINES | chart::FILL_BG;

  chart.add_line(chart_values[_chartType].field,
     chart_values[_chartType].conversion, chart_values[_chartType].color,
     flags, -0.05, 1.05);

  chart.update_values();
  chart.set_bounds(self.bounds);

  [[UIColor colorWithWhite:1 alpha:1] setFill];
  UIRectFill(self.bounds);

  chart.draw();
}

- (BOOL)isOpaque
{
  return YES;
}

@end
