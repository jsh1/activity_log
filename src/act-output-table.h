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

#ifndef ACT_OUTPUT_TABLE_H
#define ACT_OUTPUT_TABLE_H

#include "act-types.h"

#include <vector>

namespace act {

class output_table
{
  enum class cell_type
    {
      EMPTY,
      STRING,
      BAR_VALUE,
    };

  struct table_cell
    {
      cell_type type;
      int field_width;
      std::string string;
      double value;

      table_cell();
    };

  struct table_column
    {
      std::vector<table_cell> cells;
    };

  size_t _current_column;

  std::vector<table_column> _columns;

  table_cell &add_cell();

public:
  output_table();

  void print();

  void begin_row();
  void end_row();

  void output_string(int field_width, const std::string &str);
  void output_string(int field_width, const char *ptr);
  void output_value(int field_width, field_data_type type,
    double value, unit_type unit);
  void output_bar_value(int field_width, double value);
};

// implementation details

} // namespace act

#endif /* ACT_OUTPUT_TABLE_H */
