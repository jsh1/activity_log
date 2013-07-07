// -*- c-style: gnu -*-

#ifndef GPS_PARSER_H
#define GPS_PARSER_H

#include "gps-activity.h"

namespace activity_log {
namespace gps {

class parser
{
  activity &_destination;
  bool _had_error;

public:
  parser(activity &dest);
  virtual ~parser();

  virtual void parse_file(const char *path) = 0;

  void set_error() {_had_error = true;}
  bool had_error() const {return _had_error;}

  activity &destination() {return _destination;}
  const activity &destination() const {return _destination;}
};

} // namespace gps
} // namespace activity_log

#endif /* GPS_PARSER_H */
