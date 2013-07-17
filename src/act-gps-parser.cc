// -*- c-style: gnu -*-

#include "act-gps-parser.h"

#include <stdio.h>

namespace act {
namespace gps {

parser::parser(activity &dest)
: _destination(dest),
  _had_error(false)
{
}

parser::~parser()
{
}

} // namespace gps
} // namespace act
