// -*- c-style: gnu -*-

#include "gps-parser.h"

#include <stdio.h>

namespace activity_log {
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
} // namespace activity_log
