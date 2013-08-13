// -*- c-style: gnu -*-

#include "act-activity-accum.h"

#include "act-activity.h"
#include "act-config.h"
#include "act-format.h"
#include "act-output-table.h"
#include "act-util.h"

#include <cmath>

namespace act {

activity_accum::value_accum::value_accum()
: samples(0),
  sum(0),
  sum_sq(0),
  min(0),
  max(0)
{
}

void
activity_accum::value_accum::add(double x)
{
  samples++;
  sum += x;
  sum_sq += x*x;
  min = std::min(min, x);
  max = std::max(max, x);
}

double
activity_accum::value_accum::get_total() const
{
  return sum;
}

double
activity_accum::value_accum::get_mean() const
{
  return samples > 0 ? sum / samples : 0;
}

double
activity_accum::value_accum::get_sdev() const
{
  if (samples == 0)
    return 0;

  double recip = 1/samples;
  return sqrt(std::max(sum_sq * recip - (sum * recip) * (sum * recip), 0.));
}

double
activity_accum::value_accum::get_min() const
{
  return min;
}

double
activity_accum::value_accum::get_max() const
{
  return max;
}

activity_accum::activity_accum()
: _count(0)
{
}

void
activity_accum::add(const activity &a)
{
  _count++;

  if (a.distance() != 0)
    _accum[accum_distance].add(a.distance());

  if (a.duration() != 0)
    _accum[accum_duration].add(a.duration());

  if (a.speed() != 0)
    _accum[accum_speed].add(a.speed());

  if (a.max_speed() != 0)
    _accum[accum_max_speed].add(a.max_speed());

  if (a.average_hr() != 0)
    _accum[accum_average_hr].add(a.average_hr());

  if (a.max_hr() != 0)
    _accum[accum_max_hr].add(a.max_hr());

  if (a.resting_hr() != 0)
    _accum[accum_resting_hr].add(a.resting_hr());

  if (a.calories() != 0)
    _accum[accum_calories].add(a.calories());

  if (a.weight() != 0)
    _accum[accum_weight].add(a.weight());

  if (a.effort() != 0)
    _accum[accum_effort].add(a.effort());

  if (a.quality() != 0)
    _accum[accum_quality].add(a.quality());

  if (a.temperature() != 0)
    _accum[accum_temperature].add(a.temperature());

  if (a.dew_point() != 0)
    _accum[accum_dew_point].add(a.dew_point());
}

void
activity_accum::printf(const char *format, const char *key) const
{
  while (*format != 0)
    {
      if (const char *ptr = strchr(format, '%'))
	{
	  if (ptr > format)
	    fwrite(format, 1, ptr - format, stdout);

	  ptr++;

	  bool left_relative = false;
	  if (ptr[0] == '-' && isdigit(ptr[1]))
	    left_relative = true, ptr++;

	  int field_width = 0;
	  while (isdigit(*ptr))
	    field_width = field_width * 10 + (*ptr++ - '0');

	  switch (*ptr++)
	    {
	    case 'n':
	      fputc('\n', stdout);
	      break;

	    case 't':
	      fputc('\t', stdout);
	      break;

	    case '%':
	      fputc('\n', stdout);
	      break;

	    case 'x':
	      if (ptr[0] != 0 && ptr[1] != 0)
		{
		  int c0 = convert_hexdigit(ptr[0]);
		  int c1 = convert_hexdigit(ptr[1]);
		  fputc((c0 << 4) | c1, stdout);
		}
	      break;

	    case '{': {
	      const char *end = strchr(ptr, '}');
	      char token[128];
	      if (end && end - ptr < sizeof(token)-1)
		{
		  memcpy(token, ptr, end - ptr);
		  token[end - ptr] = 0;

		  char *arg = strchr(token, ':');
		  if (arg)
		    *arg++ = 0;

		  print_expansion(token, arg, key, !left_relative
				  ? field_width : -field_width);
		}
	      ptr = end ? end + 1 : ptr + strlen(ptr);
	      break; }
	    }
	  format = ptr;
	}
      else
	{
	  fputs(format, stdout);
	  break;
	}
    }
}

bool
activity_accum::get_field_value(const char *name, const char *arg,
				field_data_type &type, double &value) const
{
  field_id f_id = lookup_field_id(name);

  type = lookup_field_data_type(f_id);

  accum_id a_id;
  switch (f_id)
    {
    case field_distance:
      a_id = accum_distance;
      if (!arg)
	arg = "total";
      break;
    case field_duration:
      a_id = accum_duration;
      if (!arg)
	arg = "total";
      break;
    case field_speed:
    case field_pace:
      a_id = accum_speed;
      if (!arg)
	arg = "average";
      break;
    case field_max_speed:
    case field_max_pace:
      a_id = accum_max_speed;
      if (!arg)
	arg = "max";
      break;
    case field_average_hr:
      a_id = accum_average_hr;
      if (!arg)
	arg = "average";
      break;
    case field_max_hr:
      a_id = accum_max_hr;
      if (!arg)
	arg = "max";
      break;
    case field_resting_hr:
      a_id = accum_resting_hr;
      if (!arg)
	arg = "min";
      break;
    case field_calories:
      a_id = accum_calories;
      if (!arg)
	arg = "total";
      break;
    case field_weight:
      a_id = accum_weight;
      if (!arg)
	arg = "average";
      break;
    case field_effort:
      a_id = accum_effort;
      if (!arg)
	arg = "average";
      break;
    case field_quality:
      a_id = accum_quality;
      if (!arg)
	arg = "average";
      break;
    case field_temperature:
      a_id = accum_temperature;
      if (!arg)
	arg = "average";
      break;
    case field_dew_point:
      a_id = accum_dew_point;
      if (!arg)
	arg = "average";
      break;
    default:
      return false;
    }

  value = 0;
  if (strcasecmp(arg, "total") == 0 || strcasecmp(arg, "sum") == 0)
    value = _accum[a_id].get_total();
  else if (strcasecmp(arg, "average") == 0 || strcasecmp(arg, "mean") == 0)
    value = _accum[a_id].get_mean();
  else if (strcasecmp(arg, "sd") == 0 || strcasecmp(arg, "sdev") == 0)
    value = _accum[a_id].get_sdev();
  else if (strcasecmp(arg, "min") == 0 || strcasecmp(arg, "minimum") == 0)
    value = _accum[a_id].get_min();
  else if (strcasecmp(arg, "max") == 0 || strcasecmp(arg, "maximum") == 0)
    value = _accum[a_id].get_max();
  else
    return false;

  return true;
}

void
activity_accum::print_expansion(const char *name, const char *arg,
				const char *key, int field_width) const
{
  if (strcasecmp(name, "count") == 0)
    {
      fprintf(stdout, "%*d", field_width, _count);
    }
  else if (strcasecmp(name, "key") == 0)
    {
      fprintf(stdout, "%*s", field_width, key);
    }
  else
    {
      field_data_type type;
      double value;

      if (!get_field_value(name, arg, type, value))
	return;

      std::string str;

      switch (type)
	{
	case type_string:
	case type_date:
	case type_keywords:
	  return;

	  /* FIXME: add a way to specify custom unit conversions,
	     precision specifiers, etc. */

	case type_duration:
	case type_number:
	case type_distance:
	case type_pace:
	case type_speed:
	case type_temperature:
	case type_fraction:
	case type_weight:
	  format_value(str, type, value, unit_unknown);
	  break;
	}

      if (str.size() != 0)
	{
	  if (field_width == 0)
	    fwrite(str.c_str(), 1, str.size(), stdout);
	  else
	    fprintf(stdout, "%*s", field_width, str.c_str());
	}
    }
}

void
activity_accum::print_row(output_table &out, const char *format,
			  const char *key) const
{
  while (*format != 0)
    {
      if (const char *ptr = strchr(format, '%'))
	{
	  ptr++;

	  bool left_relative = false;
	  bool bar_value = false;

	  if (ptr[0] == '@')
	    bar_value = true, left_relative = true, ptr++;

	  if (ptr[0] == '-')
	    left_relative = !left_relative, ptr++;

	  int field_width = 0;
	  while (isdigit(*ptr))
	    field_width = field_width * 10 + (*ptr++ - '0');

	  if (left_relative)
	    {
	      field_width = std::max(field_width, 1);
	      field_width = -field_width;
	    }

	  switch (*ptr++)
	    {
	    case '{': {
	      const char *end = strchr(ptr, '}');
	      char token[128];
	      if (end && end - ptr < sizeof(token)-1)
		{
		  memcpy(token, ptr, end - ptr);
		  token[end - ptr] = 0;

		  char *arg = strchr(token, ':');
		  if (arg)
		    *arg++ = 0;

		  if (strcasecmp(token, "count") == 0)
		    {
		      if (!bar_value)
			{
			  out.output_value(field_width, type_number,
					   _count, unit_unknown);
			}
		      else
			{
			  out.output_bar_value(field_width, _count);
			}
		    }
		  else if (strcasecmp(token, "key") == 0)
		    {
		      out.output_string(field_width, key);
		    }
		  else
		    {
		      field_data_type type;
		      double value;

		      if (!get_field_value(token, arg, type, value))
			return;

		      if (!bar_value)
			{
			  out.output_value(field_width, type,
					   value, unit_unknown);
			}
		      else
			{
			  out.output_bar_value(field_width, value);
			}
		    }
		}
	      ptr = end ? end + 1 : ptr + strlen(ptr);
	      break; }
	    }
	  format = ptr;
	}
      else
	{
	  fputs(format, stdout);
	  break;
	}
    }
}

} // namespace act
