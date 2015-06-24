/* -*- c-style: gnu -*-

   Copyright (c) 2013-2014 John Harper <jsh@unfactored.org>

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

#ifndef ACT_GPS_CHART_H
#define ACT_GPS_CHART_H

#include "act-gps-activity.h"

#import <CoreGraphics/CoreGraphics.h>

namespace act {
namespace gps {

class chart
{
public:
  enum line_flags
    {
      FILL_BG = 1U << 0,
      TICK_LINES = 1U << 1,
    };

  enum class line_color
    {
      red,
      green,
      blue,
      orange,
      yellow,
      magenta,
      teal,
      steel_blue,
      tomato,
      dark_orchid,
    };

  enum class x_axis_type
    {
      distance,
      elapsed_time,
    };

  enum class value_conversion
    {
      identity,
      heartrate_bpm_hrr,
      heartrate_bpm_pmax,
      speed_ms_pace_mi,
      speed_ms_pace_km,
      speed_ms_mph,
      speed_ms_kph,
      speed_ms_vvo2max,
      distance_m_mi,
      distance_m_ft,
      distance_m_cm,
      distance_m_mm,
      time_s_ms,
    };

  chart(const activity &a, x_axis_type x_axis);

  const activity &get_activity() const;
  x_axis_type x_axis() const;

  void add_line(activity::point_field field, value_conversion conv,
    line_color color, uint32_t fill_bg, float min_ratio, float max_ratio);

  void set_bounds(const CGRect &r);		/* calls update_values() */
  const CGRect &bounds() const;

  void draw();

  void remove_all_lines();

  void update_values();

private:
  struct line
    {
      activity::point_field field;
      value_conversion conversion;
      line_color color;
      uint32_t flags;
      float min_ratio, max_ratio;

      // in "standard unit" source space
      float min_value, max_value;
      double scaled_min_value, scaled_max_value;

      // in "target unit" source space
      double tick_min, tick_max, tick_delta;

      line();
      line(activity::point_field field, value_conversion conversion,
	line_color color, uint32_t flags, float min_ratio, float max_ratio);

      void update_values(const chart &c);

      double convert_from_si(double x) const;
      double convert_to_si(double x) const;

      void format_tick(std::string &s, double tick, double value) const;
    };

  friend struct line;

  struct x_axis_state
    {
      activity::point_field field;
      activity::point::field_fn field_fn;

      double min_value;
      double max_value;

      double xm, xc;

      x_axis_state(const chart &chart, x_axis_type type);
    };

  friend struct x_axis_state;

  void draw_background() const;
  void draw_line(const line &l, const x_axis_state &xs, CGFloat tx) const;
  void draw_lap_markers(const x_axis_state &xs);

  const CGRect &chart_rect() const;

  const activity &_activity;
  x_axis_type _x_axis;
  float _min_time, _max_time;
  float _min_distance, _max_distance;
  std::vector<line> _lines;
  CGRect _bounds;
  CGRect _chart_rect;
};

// implementation details

inline const activity &
chart::get_activity() const
{
  return _activity;
}

inline chart::x_axis_type
chart::x_axis() const
{
  return _x_axis;
}

inline
chart::line::line()
{
}

inline
chart::line::line(activity::point_field field_, value_conversion conversion_,
		  line_color color_, uint32_t flags_, float min_ratio_,
		  float max_ratio_)
: field(field_),
  conversion(conversion_),
  color(color_),
  flags(flags_),
  min_ratio(min_ratio_),
  max_ratio(max_ratio_)
{
}

inline const CGRect &
chart::bounds() const
{
  return _bounds;
}

inline const CGRect &
chart::chart_rect() const
{
  return _chart_rect;
}

} // namespace chart_view
} // namespace act

#endif /* ACT_GPS_CHART_H */
