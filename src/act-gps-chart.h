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
      DISTANCE,
      DURATION,
    };

  enum class value_conversion
    {
      IDENTITY,
      HEARTRATE_BPM_HRR,
      SPEED_MS_PACE,
      DISTANCE_M_MI,
      DISTANCE_M_FT,
    };

  enum class line_color
    {
      RED,
      GREEN,
      BLUE,
      ORANGE
    };

private:
  struct line
    {
      double activity::point:: *field;
      bool smoothed;
      value_conversion conversion;
      line_color color;
      double min_ratio, max_ratio;

      // in "standard unit" source space
      double min_value, max_value;
      double scaled_min_value, scaled_max_value;

      // in "target unit" source space
      double tick_min, tick_max, tick_delta;

      line();
      line(double activity::point:: *field, bool smoothed,
	value_conversion conversion, line_color color, double min_ratio,
	double max_ratio);

      void update_values(const chart &c);

      double convert_from_si(double x) const;
      double convert_to_si(double x) const;

      void format_tick(std::string &s, double tick, double value) const;
    };

  friend struct chart::line;

  const activity &_activity;
  x_axis_type _x_axis;
  double activity::point:: *_x_axis_field;
  double _min_x_value, _max_x_value;
  std::vector<line> _lines;
  CGRect _chart_rect;

  void draw_background(CGContextRef ctx);
  void draw_line(CGContextRef ctx, const line &l);
  void draw_lap_markers(CGContextRef ctx);

public:
  chart(const activity &a, x_axis_type x_axis);

  void add_line(double activity::point:: *field, bool smoothed,
    value_conversion conv, line_color color, double min_ratio,
    double max_ratio);

  void remove_all_lines();

  void update_values();

  void set_chart_rect(const CGRect &r);		/* calls update_values() */
  const CGRect &chart_rect() const;

  void draw(CGContextRef ctx);
};

// implementation details

inline
chart::line::line()
{
}

inline
chart::line::line(double activity::point:: *field_, bool smoothed_,
		  value_conversion conversion_, line_color color_,
		  double min_ratio_, double max_ratio_)
: field(field_),
  smoothed(smoothed_),
  conversion(conversion_),
  color(color_),
  min_ratio(min_ratio_),
  max_ratio(max_ratio_)
{
}

inline const CGRect &
chart::chart_rect() const
{
  return _chart_rect;
}

} // namespace gps
} // namespace act

#endif /* TARGET_OS_IPHONE || TARGET_OS_MAC */
#endif /* ACT_GPS_CHART_H */
