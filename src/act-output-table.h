// -*- c-style: gnu -*-

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
