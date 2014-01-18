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

#ifndef ACT_GPS_FIT_PARSER_H
#define ACT_GPS_FIT_PARSER_H

#include "act-gps-parser.h"

namespace act {
namespace gps {

class fit_parser : public parser
{
  FILE *_file;
  char _buf[4096];
  size_t _buf_base, _buf_idx, _buf_size;

  unsigned int _protocol_version;
  unsigned int _profile_version;

  size_t _header_size;
  size_t _data_size;

  double _start_time;

  bool _stopped;
  double _stopped_timestamp;
  double _stopped_duration;

  uint32_t _previous_timestamp;

  enum {MAX_MESSAGE_TYPES = 16};
  struct message_type;
  struct message_field;
  message_type *_message_types[MAX_MESSAGE_TYPES];

public:
  fit_parser(activity &dest);
  ~fit_parser();

  virtual void parse_file(FILE *fh);

private:
  bool read_bytes(void *buf, size_t size);
  template<typename T> T read(bool big_endian = false);

  size_t offset() {return _buf_base + _buf_idx;}

  void read_header();
  void read_data_records();
  void read_definition_message(unsigned int local_type);
  void read_data_message(const message_type &def, uint32_t timestamp);
  int32_t read_field(const message_type &def, const message_field &field,
    int32_t invalid_value = 0);
  void skip_field (const message_field &field);
  void read_record_message(const message_type &def, uint32_t timestamp);
  void read_event_message(const message_type &def, uint32_t timestamp);
  void read_lap_message(const message_type &def, uint32_t timestamp);
  void read_session_message(const message_type &def, uint32_t timestamp);
  void skip_message(const message_type &def);
};

} // namespace gps
} // namespace act

#endif /* ACT_GPS_FIT_PARSER_H */
