// -*- c-style: gnu -*-

#ifndef ACT_GPS_CHART_H
#define ACT_GPS_CHART_H

#include "act-gps-activity.h"

#if TARGET_OS_IPHONE || TARGET_OS_MAC

#if TARGET_OS_IPHONE
# include <CoreGraphics/CoreGraphics.h>
#elif TARGET_OS_MAC
# include <ApplicationServices/ApplicationServices.h>
#endif

namespace act {
namespace gps {

class chart
{
public:
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
    };

  enum class line_color
    {
      red,
      green,
      blue,
      orange,
      gray
    };

  enum line_flags
    {
      FILL_BG = 1U << 0,
      OPAQUE_BG = 1U << 1,
      NO_STROKE = 1U << 2,
      TICK_LINES = 1U << 3,
      RIGHT_TICKS = 1U << 4,
    };

  chart(const activity &a, x_axis_type x_axis);

  const activity &get_activity() const;
  x_axis_type x_axis() const;

  void add_line(double activity::point:: *field, value_conversion conv,
    line_color color, uint32_t fill_bg, double min_ratio, double max_ratio);

  void set_selected_lap(int idx);
  int selected_lap() const;

  void set_current_time(double t);
  double current_time() const;

  bool point_at_x(CGFloat x, x_axis_type type, activity::point &ret_p) const;

  void remove_all_lines();

  void update_values();

  void set_chart_rect(const CGRect &r);		/* calls update_values() */
  const CGRect &chart_rect() const;

  virtual void draw() = 0;

  virtual CGRect current_time_rect() const = 0;

protected:
  struct line
    {
      double activity::point:: *field;
      value_conversion conversion;
      line_color color;
      uint32_t flags;
      double min_ratio, max_ratio;

      // in "standard unit" source space
      double min_value, max_value;
      double scaled_min_value, scaled_max_value;

      // in "target unit" source space
      double tick_min, tick_max, tick_delta;

      line();
      line(double activity::point:: *field, value_conversion conversion,
	line_color color, uint32_t flags, double min_ratio, double max_ratio);

      void update_values(const chart &c);

      double convert_from_si(double x) const;
      double convert_to_si(double x) const;

      void format_tick(std::string &s, double tick, double value) const;
    };

  friend struct line;

  struct x_axis_state
    {
      double activity::point:: *field;

      double min_value;
      double max_value;

      CGFloat xm, xc;

      x_axis_state(const chart &chart, x_axis_type type);
    };

  friend struct x_axis_state;

  const activity &_activity;
  x_axis_type _x_axis;
  double _min_time, _max_time;
  double _min_distance, _max_distance;
  std::vector<line> _lines;
  CGRect _chart_rect;
  int _selected_lap;
  double _current_time;
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
chart::line::line(double activity::point:: *field_, value_conversion
		  conversion_, line_color color_, uint32_t flags_,
		  double min_ratio_, double max_ratio_)
: field(field_),
  conversion(conversion_),
  color(color_),
  flags(flags_),
  min_ratio(min_ratio_),
  max_ratio(max_ratio_)
{
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

} // namespace gps
} // namespace act

#endif /* TARGET_OS_IPHONE || TARGET_OS_MAC */
#endif /* ACT_GPS_CHART_H */
