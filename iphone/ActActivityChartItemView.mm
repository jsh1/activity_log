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

@implementation ActActivityChartItemView

@synthesize activity = _activity;
@synthesize chartType = _chartType;
@synthesize smoothing = _smoothing;

- (void)reloadData
{
  _chart.reset();

  [self setNeedsDisplay];
}

- (void)updateChart
{
  using namespace act::gps;

  if (_chart)
    _chart.reset();

  const act::activity *a = _activity;
  if (a == nullptr)
    return;

  const act::gps::activity *gps_a = a->gps_data();
  if (gps_a == nullptr)
    return;

  if (!_smoothed_data
      || _data_smoothing != _smoothing
      || _smoothed_data->start_time() != gps_a->start_time()
      || _smoothed_data->total_distance() != gps_a->total_distance()
      || _smoothed_data->total_duration() != gps_a->total_duration())
    {
      if (_smoothing > 0)
	{
	  _smoothed_data.reset(new act::gps::activity);
	  _smoothed_data->smooth(*gps_a, _smoothing);
	}
      else if (_smoothed_data)
	_smoothed_data.reset();

      _data_smoothing = _smoothing;
    }

  const act::gps::activity *data = _smoothed_data.get();
  if (data == nullptr)
    data = gps_a;

  _chart.reset(new chart(*data, chart::x_axis_type::distance));

  auto field = activity::point_field::distance;
  auto conv = chart::value_conversion::identity;
  auto color = chart::line_color::gray;
  uint32_t flags = chart::TICK_LINES;

  switch (_chartType)
    {
    case ActActivityChartSpeed:
      field = activity::point_field::speed;
      conv = chart::value_conversion::speed_ms_pace_mi;
      color = chart::line_color::blue;
      break;

    case ActActivityChartHeartRate:
      field = activity::point_field::heart_rate;
      color = chart::line_color::orange;
      break;

    case ActActivityChartAltitude:
      field = activity::point_field::altitude;
      conv = chart::value_conversion::distance_m_ft;
      color = chart::line_color::green;
      break;

    case ActActivityChartCadence:
      field = activity::point_field::cadence;
      color = chart::line_color::tomato;
      break;

    case ActActivityChartStrideLength:
      field = activity::point_field::stride_length;
      color = chart::line_color::dark_orchid;
      break;

    case ActActivityChartVerticalOscillation:
      field = activity::point_field::vertical_oscillation;
      color = chart::line_color::teal;
      break;

    case ActActivityChartStanceTime:
      field = activity::point_field::stance_time;
      color = chart::line_color::steel_blue;
      break;
    }

  _chart->add_line(field, conv, color, flags, -0.05, 1.05);
  _chart->set_chart_rect(self.bounds);
  _chart->set_selected_lap(-1);
  _chart->update_values();
}

- (void)drawRect:(CGRect)clip
{
  if (_chart == nullptr && _activity != nullptr)
    [self updateChart];

  if (_chart != nullptr)
    {
     [[UIColor colorWithWhite:1 alpha:1] setFill];
      UIRectFill(self.bounds);

      _chart->set_chart_rect(self.bounds);
      _chart->draw();
    }
}

- (BOOL)isOpaque
{
  return YES;
}

@end
