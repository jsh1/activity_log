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

#ifndef ACT_GPS_CHART_H
#define ACT_GPS_CHART_H

#include "act-gps-activity.h"

#import <CoreGraphics/CoreGraphics.h>

namespace act {
namespace chart_view {

enum line_flags
{
  FILL_BG = 1U << 0,
  OPAQUE_BG = 1U << 1,
  NO_STROKE = 1U << 2,
  TICK_LINES = 1U << 3,
  RIGHT_TICKS = 1U << 4,
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
  gray
};

enum class x_axis_type
{
  distance,
  elapsed_time,
};

enum class value_conversion
{
  identity,
  percentage,
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

class chart
{
public:
  chart(const gps::activity &a, x_axis_type x_axis);

  const gps::activity &get_activity() const;
  x_axis_type x_axis() const;

  void add_line(gps::activity::point_field field, value_conversion conv,
    line_color color, uint32_t fill_bg, float min_ratio, float max_ratio);

  void set_selected_lap(int idx);
  int selected_lap() const;

  void set_current_time(double t);
  double current_time() const;

  void set_chart_rect(const CGRect &r);		/* calls update_values() */
  const CGRect &chart_rect() const;

  void set_backing_scale(CGFloat scale);
  CGFloat backing_scale() const;

  void draw();

  CGRect current_time_rect() const;

  bool point_at_x(double x, gps::activity::point &ret_p) const;

  void remove_all_lines();

  void update_values();

protected:
  struct line
    {
      gps::activity::point_field field;
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
      line(gps::activity::point_field field, value_conversion conversion,
	line_color color, uint32_t flags, float min_ratio, float max_ratio);

      void update_values(const chart &c);

      double convert_from_si(double x) const;
      double convert_to_si(double x) const;

      void format_tick(std::string &s, double tick, double value) const;
    };

  friend struct line;

  struct x_axis_state
    {
      gps::activity::point_field field;
      gps::activity::point::field_fn field_fn;

      double min_value;
      double max_value;

      double xm, xc;

      x_axis_state(const chart &chart, x_axis_type type);
    };

  friend struct x_axis_state;

  const gps::activity &_activity;
  x_axis_type _x_axis;
  float _min_time, _max_time;
  float _min_distance, _max_distance;
  std::vector<line> _lines;
  int _selected_lap;
  double _current_time;
  CGRect _chart_rect;
  CGFloat _backing_scale;
  CGFloat _backing_scale_recip;

private:
  void draw_line(const line &l, const x_axis_state &xs, CGFloat tx);
  void draw_lap_markers(const x_axis_state &xs);
  void draw_current_time();

  CGFloat backing_scale_recip() const;
  CGFloat round_to_pixels(CGFloat x) const;
};

// implementation details

inline const gps::activity &
chart::get_activity() const
{
  return _activity;
}

inline x_axis_type
chart::x_axis() const
{
  return _x_axis;
}

inline
chart::line::line()
{
}

inline
chart::line::line(gps::activity::point_field field_,
		  value_conversion conversion_, line_color color_,
		  uint32_t flags_, float min_ratio_, float max_ratio_)
: field(field_),
  conversion(conversion_),
  color(color_),
  flags(flags_),
  min_ratio(min_ratio_),
  max_ratio(max_ratio_)
{
}

inline void
chart::set_selected_lap(int idx)
{
  _selected_lap = idx;
}

inline int
chart::selected_lap() const
{
  return _selected_lap;
}

inline void
chart::set_current_time(double t)
{
  _current_time = t;
}

inline double
chart::current_time() const
{
  return _current_time;
}

inline void
chart::set_chart_rect(const CGRect &r)
{
  _chart_rect = r;
}

inline const CGRect &
chart::chart_rect() const
{
  return _chart_rect;
}

inline void
chart::set_backing_scale(CGFloat scale)
{
  _backing_scale = scale;
  _backing_scale_recip = 1 / scale;
}

inline CGFloat
chart::backing_scale() const
{
  return _backing_scale;
}

inline CGFloat
chart::backing_scale_recip() const
{
  return _backing_scale_recip;
}

inline CGFloat
chart::round_to_pixels(CGFloat x) const
{
  return round(x * _backing_scale) * _backing_scale_recip;
}

} // namespace chart_view
} // namespace act

#endif /* ACT_GPS_CHART_H */
