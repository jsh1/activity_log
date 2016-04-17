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

#include "act-activity-accum.h"

#include "act-activity.h"
#include "act-config.h"
#include "act-format.h"
#include "act-output-table.h"
#include "act-util.h"

#include <cmath>
#include <cfloat>

namespace act {

activity_accum::value_accum::value_accum(accum_field f)
: field(f),
  samples(0),
  sum(0),
  sum_sq(0),
  min(DBL_MAX),
  max(DBL_MIN)
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

bool
activity_accum::field_by_name(const char *name, accum_field &ret)
{
  field_id f_id = lookup_field_id(name);

  switch (f_id)
    {
    case field_id::distance:
      ret = accum_field::distance;
      return true;
    case field_id::duration:
      ret = accum_field::duration;
      return true;
    case field_id::speed:
    case field_id::pace:
      ret = accum_field::speed;
      return true;
    case field_id::max_speed:
    case field_id::max_pace:
      ret = accum_field::max_speed;
      return true;
    case field_id::avg_hr:
      ret = accum_field::avg_hr;
      return true;
    case field_id::max_hr:
      ret = accum_field::max_hr;
      return true;
    case field_id::resting_hr:
      ret = accum_field::resting_hr;
      return true;
    case field_id::avg_cadence:
      ret = accum_field::avg_cadence;
      return true;
    case field_id::max_cadence:
      ret = accum_field::max_cadence;
      return true;
    case field_id::avg_stance_time:
      ret = accum_field::avg_stance_time;
      return true;
    case field_id::avg_stance_ratio:
      ret = accum_field::avg_stance_ratio;
      return true;
    case field_id::avg_stride_length:
      ret = accum_field::avg_stride_length;
      return true;
    case field_id::avg_vertical_oscillation:
      ret = accum_field::avg_vertical_oscillation;
      return true;
    case field_id::calories:
      ret = accum_field::calories;
      return true;
    case field_id::training_effect:
      ret = accum_field::training_effect;
      return true;
    case field_id::weight:
      ret = accum_field::weight;
      return true;
    case field_id::effort:
      ret = accum_field::effort;
      return true;
    case field_id::quality:
      ret = accum_field::quality;
      return true;
    case field_id::points:
      ret = accum_field::points;
      return true;
    case field_id::temperature:
      ret = accum_field::temperature;
      return true;
    case field_id::dew_point:
      ret = accum_field::dew_point;
      return true;
    default:
      return false;
    }
}

std::vector<activity_accum::accum_field>
activity_accum::format_fields(const char *format)
{
  std::vector<accum_field> fields;

  if (format != nullptr)
    {
      while (*format != 0)
	{
	  if (const char *ptr = strchr(format, '%'))
	    {
	      ptr++;

	      if (ptr[0] == '@')
		ptr++;
	      if (ptr[0] == '-')
		ptr++;
	      while (isdigit(*ptr))
		ptr++;

	      switch (*ptr++)
		{
		case 'x':
		  if (ptr[0] != 0 && ptr[1] != 0)
		    ptr += 2;
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

		      accum_field field;
		      if (field_by_name(token, field)
			  && std::find(fields.begin(), fields.end(),
				       field) == fields.end())
			{
			  fields.push_back(field);
			}
		    }
		  ptr = end ? end + 1 : ptr + strlen(ptr);
		  break; }
		}
	      format = ptr;
	    }
	}
    }

  return fields;
}

activity_accum::activity_accum(const std::vector<accum_field> &fields)
: _count(0)
{
  for (accum_field field : fields)
    _accum.push_back(value_accum(field));
}

void
activity_accum::add(const activity &a)
{
  _count++;

  for (auto &accum : _accum)
    {
      switch(accum.field)
	{
	case accum_field::distance:
	  if (double x = a.distance())
	    accum.add(x);
	  break;

	case accum_field::duration:
	  if (double x = a.duration())
	    accum.add(x);
	  break;

	case accum_field::speed:
	  if (double x = a.speed())
	    accum.add(x);
	  break;

	case accum_field::max_speed:
	  if (double x = a.max_speed())
	    accum.add(x);
	  break;

	case accum_field::avg_hr:
	  if (double x = a.avg_hr())
	    accum.add(x);
	  break;

	case accum_field::max_hr:
	  if (double x = a.max_hr())
	    accum.add(x);
	  break;

	case accum_field::resting_hr:
	  if (double x = a.resting_hr())
	    accum.add(x);
	  break;

	case accum_field::avg_cadence:
	  if (double x = a.avg_cadence())
	    accum.add(x);
	  break;

	case accum_field::max_cadence:
	  if (double x = a.max_cadence())
	    accum.add(x);
	  break;

	case accum_field::avg_stance_time:
	  if (double x = a.avg_stance_time())
	    accum.add(x);
	  break;

	case accum_field::avg_stance_ratio:
	  if (double x = a.avg_stance_ratio())
	    accum.add(x);
	  break;

	case accum_field::avg_vertical_oscillation:
	  if (double x = a.avg_vertical_oscillation())
	    accum.add(x);
	  break;

	case accum_field::avg_stride_length:
	  if (double x = a.avg_stride_length())
	    accum.add(x);
	  break;

	case accum_field::calories:
	  if (double x = a.calories())
	    accum.add(x);
	  break;

	case accum_field::training_effect:
	  if (double x = a.training_effect())
	    accum.add(x);
	  break;

	case accum_field::weight:
	  if (double x = a.weight())
	    accum.add(x);
	  break;

	case accum_field::effort:
	  if (double x = a.effort())
	    accum.add(x);
	  break;

	case accum_field::quality:
	  if (double x = a.quality())
	    accum.add(x);
	  break;

	case accum_field::points:
	  if (double x = a.points())
	    accum.add(x);
	  break;

	case accum_field::temperature:
	  if (double x = a.temperature())
	    accum.add(x);
	  break;

	case accum_field::dew_point:
	  if (double x = a.dew_point())
	    accum.add(x);
	  break;
	}
    }
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
  accum_field field;
  if (!field_by_name(name, field))
    return false;

  if (arg == nullptr)
    {
      switch (field)
	{
	case accum_field::calories:
	case accum_field::distance:
	case accum_field::duration:
	case accum_field::points:
	  arg = "total";
	  break;
	case accum_field::avg_cadence:
	case accum_field::avg_hr:
	case accum_field::avg_stance_ratio:
	case accum_field::avg_stance_time:
	case accum_field::avg_stride_length:
	case accum_field::avg_vertical_oscillation:
	case accum_field::dew_point:
	case accum_field::effort:
	case accum_field::quality:
	case accum_field::speed:
	case accum_field::temperature:
	case accum_field::training_effect:
	case accum_field::weight:
	  arg = "average";
	  break;
	case accum_field::max_cadence:
	case accum_field::max_hr:
	case accum_field::max_speed:
	  arg = "max";
	  break;
	case accum_field::resting_hr:
	  arg = "min";
	  break;
	}
    }

  const value_accum *accum = nullptr;
  for (const auto &a : _accum)
    {
      if (a.field == field)
	{
	  accum = &a;
	  break;
	}
    }

  if (accum == nullptr || arg == nullptr)
    return false;

  value = 0;
  if (strcasecmp(arg, "total") == 0 || strcasecmp(arg, "sum") == 0)
    value = accum->get_total();
  else if (strcasecmp(arg, "average") == 0 || strcasecmp(arg, "mean") == 0)
    value = accum->get_mean();
  else if (strcasecmp(arg, "sd") == 0 || strcasecmp(arg, "sdev") == 0)
    value = accum->get_sdev();
  else if (strcasecmp(arg, "min") == 0 || strcasecmp(arg, "minimum") == 0)
    value = accum->get_min();
  else if (strcasecmp(arg, "max") == 0 || strcasecmp(arg, "maximum") == 0)
    value = accum->get_max();
  else
    return false;

  type = lookup_field_data_type(lookup_field_id(name));

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
	case field_data_type::string:
	case field_data_type::date:
	case field_data_type::keywords:
	  return;

	  /* FIXME: add a way to specify custom unit conversions,
	     precision specifiers, etc. */

	case field_data_type::duration:
	case field_data_type::number:
	case field_data_type::distance:
	case field_data_type::pace:
	case field_data_type::speed:
	case field_data_type::temperature:
	case field_data_type::fraction:
	case field_data_type::weight:
	case field_data_type::heart_rate:
	case field_data_type::cadence:
	case field_data_type::efficiency:
	  format_value(str, type, value, unit_type::unknown);
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
			  out.output_value(field_width, field_data_type::number,
					   _count, unit_type::unknown);
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
					   value, unit_type::unknown);
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
