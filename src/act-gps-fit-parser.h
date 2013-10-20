// -*- c-style: gnu -*-

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

  uint32_t _previous_timestamp;

  enum {MAX_MESSAGE_TYPES = 16};
  struct message_type;
  struct message_field;
  message_type *_message_types[MAX_MESSAGE_TYPES];

  std::vector<activity::point> _records;

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
  void read_lap_message(const message_type &def, uint32_t timestamp);
  void read_session_message(const message_type &def, uint32_t timestamp);
  void skip_message(const message_type &def);
};

} // namespace gps
} // namespace act

#endif /* ACT_GPS_FIT_PARSER_H */
