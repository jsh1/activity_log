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

#include "act-output-table.h"

#include "act-format.h"

#include <algorithm>
#include <assert.h>

namespace act {

output_table::table_cell::table_cell()
: type(cell_type::EMPTY),
  field_width(0),
  value(0)
{
}

output_table::output_table()
: _current_column(0)
{
}

void
output_table::print()
{
  size_t total_columns = _columns.size();
  if (total_columns == 0)
    return;

  size_t total_rows = _columns[0].cells.size();
  if (total_rows == 0)
    return;

  std::vector<int> widths;
  widths.resize(total_columns);
  std::vector<double> values;
  values.resize(total_columns);

  int total_width = 0;
  size_t bar_count = 0;

  for (size_t i = 0; i < total_columns; i++)
    {
      table_column &col = _columns[i];

      if (col.cells[0].type == cell_type::STRING)
	{
	  int max_width = 0;
	  for (size_t j = 0; j < total_rows; j++)
	    max_width = std::max(max_width, (int)col.cells[j].string.size());

	  widths[i] = max_width;
	  total_width += max_width + 1;
	}
      else if (col.cells[0].type == cell_type::BAR_VALUE)
	{
	  double max_value = 0;
	  for (size_t j = 0; j < total_rows; j++)
	    max_value = std::max(max_value, col.cells[j].value);

	  values[i] = max_value;
	  bar_count++;
	}
    }

  if (bar_count != 0)
    {
      const int min_bar_width = 16;
      const int output_width = 72;

      int bar_width;

      if (total_width + bar_count * min_bar_width < output_width)
	bar_width = (output_width - total_width) / bar_count;
      else
	bar_width = min_bar_width;

      for (size_t i = 0; i < total_columns; i++)
	{
	  table_column &col = _columns[i];

	  if (col.cells[0].type == cell_type::BAR_VALUE)
	    {
	      widths[i] = bar_width;
	      total_width += bar_width + 1;
	    }
	}
    }

  for (size_t j = 0; j < total_rows; j++)
    {
      for (size_t i = 0; i < total_columns; i++)
	{
	  table_column &col = _columns[i];
	  table_cell &cell = col.cells[j];

	  int width = std::max(abs(cell.field_width), widths[i]);
	  bool left_relative = cell.field_width < 0;

	  char *buf = (char *)alloca(width + 2);
	  char *ptr = buf;

	  int cell_width = 0;
	  if (cell.type == cell_type::STRING)
	    cell_width = (int) cell.string.size();
	  else if (cell.type == cell_type::BAR_VALUE)
	    cell_width = (int) ((cell.value / values[i]) * width + .5);

	  int gap_width = std::max(width - cell_width, 0);

	  if (!left_relative)
	    memset(ptr, ' ', gap_width), ptr += gap_width;

	  if (cell.type == cell_type::STRING)
	    memcpy(ptr, cell.string.c_str(), cell_width);
	  else if (cell.type == cell_type::BAR_VALUE)
	    memset(ptr, '#', cell_width);
	  ptr += cell_width;

	  if (left_relative)
	    memset(ptr, ' ', gap_width), ptr += gap_width;

	  *ptr++ = i + 1 == total_columns ? '\n' : ' ';
	  *ptr++ = 0;

	  assert(ptr - buf == width + 2);

	  fputs(buf, stdout);
	}
    }
}

void
output_table::begin_row()
{
}

void
output_table::end_row()
{
  _current_column = 0;
}

void
output_table::output_string(int field_width, const std::string &str)
{
  table_cell &cell = add_cell();
  cell.type = cell_type::STRING;
  cell.string = str;
  cell.field_width = field_width;
}

void
output_table::output_string(int field_width, const char *ptr)
{
  table_cell &cell = add_cell();
  cell.type = cell_type::STRING;
  cell.string = ptr;
  cell.field_width = field_width;
}

void
output_table::output_value(int field_width, field_data_type type,
			   double value, unit_type unit)
{
  table_cell &cell = add_cell();
  cell.type = cell_type::STRING;
  format_value(cell.string, type, value, unit);
  cell.field_width = field_width;
}

void
output_table::output_bar_value(int field_width, double value)
{
  table_cell &cell = add_cell();
  cell.type = cell_type::BAR_VALUE;
  cell.value = value;
  cell.field_width = field_width;
}

output_table::table_cell &
output_table::add_cell()
{
  if (_columns.size() <= _current_column)
    _columns.resize(_current_column + 1);

  table_column &col = _columns[_current_column];

  col.cells.resize(col.cells.size() + 1);
  _current_column++;

  return col.cells.back();
}

} // namespace act
