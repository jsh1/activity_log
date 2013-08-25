// -*- c-style: gnu -*-

#ifndef ACT_GPS_TCX_PARSER_H
#define ACT_GPS_TCX_PARSER_H

#include "act-gps-parser.h"

#include <libxml/parser.h>

namespace act {
namespace gps {

class tcx_parser : public parser
{
  enum class state
    {
      ROOT,
      TRAINING_CENTER_DATABASE,
      ACTIVITIES,
      ACTIVITY,
      ACTIVITY_ID,
      LAP,
      LAP_TOTAL_TIME,
      LAP_DISTANCE,
      LAP_AVG_SPEED,
      LAP_MAX_SPEED,
      LAP_CALORIES,
      LAP_AVG_HEART_RATE,
      LAP_MAX_HEART_RATE,
      LAP_EXTENSIONS,
      LAP_LX,
      TRACK,
      TRACKPOINT,
      TP_TIME,
      TP_POSITION,
      TP_LAT,
      TP_LONG,
      TP_ALTITUDE,
      TP_DISTANCE,
      TP_SPEED,
      TP_HEART_RATE,
      TP_EXTENSIONS,
      TP_TPX,
      VALUE,
      UNKNOWN,
    };

  xmlSAXHandler _sax_vtable;
  xmlParserCtxtPtr _ctx;

  std::vector<state> _state;
  std::string *_characters;

public:
  tcx_parser(activity &dest);
  ~tcx_parser();

  virtual void parse_file(const char *path);

private:
  void push_state(state x) {_state.push_back(x);}
  void pop_state() {_state.pop_back();}

  state current_state() {return _state.back();}
  state previous_state() {return _state[_state.size()-2];}

  activity::lap &current_lap() {return destination().laps().back();}
  activity::point &current_point() {return current_lap().track.back();}

  static void sax_start_element(void *ctx, const xmlChar *name,
    const xmlChar *pfx, const xmlChar *uri, int n_ns, const xmlChar **ns,
    int n_attr, int n_default_attr, const xmlChar **attr);
  static void sax_characters(void *ctx, const xmlChar *ptr, int size);
  static void sax_end_element(void *ctx, const xmlChar *name,
    const xmlChar *pfx, const xmlChar *uri);
  static void sax_warning(void *ctx, const char *msg, ...);
  static void sax_error(void *ctx, const char *msg, ...);
};

} // namespace gps
} // namespace act

#endif /* ACT_GPS_TCX_PARSER_H */
