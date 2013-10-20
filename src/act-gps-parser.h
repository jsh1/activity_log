// -*- c-style: gnu -*-

#ifndef ACT_GPS_PARSER_H
#define ACT_GPS_PARSER_H

#include "act-gps-activity.h"

namespace act {
namespace gps {

class parser
{
  activity &_destination;
  bool _had_error;

public:
  parser(activity &dest);
  virtual ~parser();

  virtual void parse_file(FILE *fh) = 0;

  void set_error() {_had_error = true;}
  bool had_error() const {return _had_error;}

  activity &destination() {return _destination;}
  const activity &destination() const {return _destination;}
};

} // namespace gps
} // namespace act

#endif /* ACT_GPS_PARSER_H */
