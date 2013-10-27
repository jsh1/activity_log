// -*- c-style: gnu -*-

#include "act-gps-tcx-parser.h"

#include <stdlib.h>
#include <time.h>
#include <xlocale.h>

#define TRAINING_CENTER_NS "http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2"
#define ACTIVITY_EXTENSION_NS "http://www.garmin.com/xmlschemas/ActivityExtension/v2"
#define LOG_ERRORS 1

namespace act {
namespace gps {

tcx_parser::tcx_parser(activity &dest)
: parser(dest),
  _ctx(nullptr),
  _state(1, state::ROOT),
  _characters(nullptr)
{
  memset(&_sax_vtable, 0, sizeof(_sax_vtable));
  _sax_vtable.initialized = XML_SAX2_MAGIC;
  _sax_vtable.startElementNs = sax_start_element;
  _sax_vtable.endElementNs = sax_end_element;
  _sax_vtable.characters = sax_characters;
  _sax_vtable.warning = sax_warning;
  _sax_vtable.error = sax_error;
  _sax_vtable.fatalError = sax_error;

  _ctx = xmlCreatePushParserCtxt(&_sax_vtable, this, nullptr, 0, nullptr);
  if (!_ctx)
    set_error ();
}

tcx_parser::~tcx_parser()
{
  if (_ctx)
    xmlFreeParserCtxt(_ctx);

  if (_characters)
    delete _characters;
}

void
tcx_parser::parse_file(FILE *fh)
{
  if (had_error())
    return;

  char buffer[BUFSIZ];
  while (size_t size = fread(buffer, 1, BUFSIZ, fh))
    xmlParseChunk(_ctx, buffer, size, false);

  xmlParseChunk(_ctx, "", 0, true);

  destination().update_summary();

  if (!had_error())
    destination().update_region();
}

namespace {

const char whitespace[] = " \t\n\r\f";

double
parse_double(const std::string &s)
{
  return strtod_l(s.c_str(), nullptr, nullptr);
}

double
parse_time(const std::string &s)
{
  size_t start = s.find_first_not_of(whitespace);
  if (start == std::string::npos)
    return 0;

  struct tm tm = {0};
  double seconds_frac = 0;

  if (sscanf_l(s.c_str() + start, nullptr, "%4d-%2d-%2dT%2d:%2d:%2d%lf",
	       &tm.tm_year, &tm.tm_mon, &tm.tm_mday, &tm.tm_hour,
	       &tm.tm_min, &tm.tm_sec, &seconds_frac) != 7)
    return 0;

  tm.tm_year = tm.tm_year - 1900;
  tm.tm_mon = tm.tm_mon - 1;		// 0..11

  time_t epoch_time = timegm(&tm);
  if (epoch_time == -1)
    return 0;

  return epoch_time + seconds_frac;
}

bool
find_attr(std::string &result, int n_attr,
	  const xmlChar **attr, const char *name)
{
  // attr is [localname, prefix, uri, start-ptr, end-ptr] ...

  for (const xmlChar **ptr = attr; ptr[0]; ptr += 5)
    {
      if (strcmp((const char *)ptr[0], name) == 0)
	{
	  result = std::string((const char *)ptr[3], ptr[4] - ptr[3]);
	  return true;
	}
    }

  return false;
}

} // anonymous namespace

void
tcx_parser::sax_start_element(void *ctx, const xmlChar *name,
  const xmlChar *pfx, const xmlChar *uri, int n_ns, const xmlChar **ns,
  int n_attr, int n_default_attr, const xmlChar **attr)
{
  tcx_parser *p = static_cast<tcx_parser *>(ctx);

  state new_state = state::UNKNOWN;

  if (uri && strcmp((const char *)uri, TRAINING_CENTER_NS) == 0)
    {
      switch (p->current_state())
	{
	case state::ROOT:
	  if (strcmp((const char *)name, "TrainingCenterDatabase") == 0)
	    new_state = state::TRAINING_CENTER_DATABASE;
	  break;
	case state::TRAINING_CENTER_DATABASE:
	  if (strcmp((const char *)name, "Activities") == 0)
	    new_state = state::ACTIVITIES;
	  break;
	case state::ACTIVITIES:
	  if (strcmp((const char *)name, "Activity") == 0)
	    {
	      new_state = state::ACTIVITY;
	      std::string s;
	      if (find_attr(s, n_attr, attr, "Sport"))
		{
		  activity::sport_type sport = activity::sport_type::unknown;
		  if (s == "Running")
		    sport = activity::sport_type::running;
		  else if (s == "Cycling")
		    sport = activity::sport_type::cycling;
		  else if (s == "Swimming")
		    sport = activity::sport_type::swimming;
		  p->destination().set_sport(sport);
		}
	    }
	  break;
	case state::ACTIVITY:
	  if (strcmp((const char *)name, "Id") == 0)
	    new_state = state::ACTIVITY_ID;
	  else if (strcmp((const char *)name, "Lap") == 0)
	    {
	      new_state = state::LAP;
	      p->destination().laps().push_back(activity::lap());
	      std::string s;
	      if (find_attr(s, n_attr, attr, "StartTime"))
		p->current_lap().start_time = parse_time(s);
	    }
	  break;
	case state::LAP:
	  if (strcmp((const char *)name, "TotalTimeSeconds") == 0)
	    new_state = state::LAP_TOTAL_TIME;
	  else if (strcmp((const char *)name, "DistanceMeters") == 0)
	    new_state = state::LAP_DISTANCE;
	  else if (strcmp((const char *)name, "MaximumSpeed") == 0)
	    new_state = state::LAP_MAX_SPEED;
	  else if (strcmp((const char *)name, "Calories") == 0)
	    new_state = state::LAP_CALORIES;
	  else if (strcmp((const char *)name, "AverageHeartRateBpm") == 0)
	    new_state = state::LAP_AVG_HEART_RATE;
	  else if (strcmp((const char *)name, "MaximumHeartRateBpm") == 0)
	    new_state = state::LAP_MAX_HEART_RATE;
	  else if (strcmp((const char *)name, "Track") == 0)
	    new_state = state::TRACK;
	  else if (strcmp((const char *)name, "Extensions") == 0)
	    new_state = state::LAP_EXTENSIONS;
	  break;
	case state::TRACK:
	  if (strcmp((const char *)name, "Trackpoint") == 0)
	    {
	      new_state = state::TRACKPOINT;
	      p->current_lap().track.push_back(activity::point());
	    }
	  break;
	case state::TRACKPOINT:
	  if (strcmp((const char *)name, "Time") == 0)
	    new_state = state::TP_TIME;
	  else if (strcmp((const char *)name, "Position") == 0)
	    new_state = state::TP_POSITION;
	  else if (strcmp((const char *)name, "AltitudeMeters") == 0)
	    new_state = state::TP_ALTITUDE;
	  else if (strcmp((const char *)name, "DistanceMeters") == 0)
	    new_state = state::TP_DISTANCE;
	  else if (strcmp((const char *)name, "HeartRateBpm") == 0)
	    new_state = state::TP_HEART_RATE;
	  else if (strcmp((const char *)name, "Extensions") == 0)
	    new_state = state::TP_EXTENSIONS;
	  break;
	case state::TP_POSITION:
	  if (strcmp((const char *)name, "LatitudeDegrees") == 0)
	    new_state = state::TP_LAT;
	  else if (strcmp((const char *)name, "LongitudeDegrees") == 0)
	    new_state = state::TP_LONG;
	  break;
	case state::LAP_AVG_HEART_RATE:
	case state::LAP_MAX_HEART_RATE:
	case state::TP_HEART_RATE:
	  if (strcmp((const char *)name, "Value") == 0)
	    new_state = state::VALUE;
	  break;
	default:
	  break;
	}
    }
  else if (uri && strcmp((const char *)uri, ACTIVITY_EXTENSION_NS) == 0)
    {
      switch (p->current_state())
	{
	case state::LAP_EXTENSIONS:
	  if (strcmp((const char *)name, "LX") == 0)
	    new_state = state::LAP_LX;
	  break;
	case state::LAP_LX:
	  if (strcmp((const char *)name, "AvgSpeed") == 0)
	    new_state = state::LAP_AVG_SPEED;
	  break;
	case state::TP_EXTENSIONS:
	  if (strcmp((const char *)name, "TPX") == 0)
	    new_state = state::TP_TPX;
	  break;
	case state::TP_TPX:
	  if (strcmp((const char *)name, "Speed") == 0)
	    new_state = state::TP_SPEED;
	  break;
	default:
	  break;
	}
    }

  p->push_state(new_state);

  if (p->_characters)
    delete p->_characters, p->_characters = nullptr;
}

void
tcx_parser::sax_characters(void *ctx, const xmlChar *ptr, int size)
{
  tcx_parser *p = static_cast<tcx_parser *>(ctx);

  switch (p->current_state())
    {
    case state::ACTIVITY_ID:
    case state::LAP_TOTAL_TIME:
    case state::LAP_DISTANCE:
    case state::LAP_AVG_SPEED:
    case state::LAP_MAX_SPEED:
    case state::LAP_CALORIES:
    case state::TP_TIME:
    case state::TP_LAT:
    case state::TP_LONG:
    case state::TP_ALTITUDE:
    case state::TP_DISTANCE:
    case state::TP_SPEED:
    case state::VALUE:
      if (!p->_characters)
	p->_characters = new std::string((const char *)ptr, size);
      else
	p->_characters->append((const char *)ptr, size);
      break;

    default:
      break;
    }
}

void
tcx_parser::sax_end_element(void *ctx, const xmlChar *name,
			    const xmlChar *pfx, const xmlChar *uri)
{
  tcx_parser *p = static_cast<tcx_parser *>(ctx);

  if (p->_characters)
    {
      switch (p->current_state())
	{
	case state::ACTIVITY_ID:
	  /* FIXME: trim whitespace. */
	  p->destination().set_activity_id(*p->_characters);
	  break;
	case state::LAP_TOTAL_TIME:
	  p->current_lap().total_duration = parse_double(*p->_characters);
	  break;
	case state::LAP_DISTANCE:
	  p->current_lap().total_distance = parse_double(*p->_characters);
	  break;
	case state::LAP_AVG_SPEED:
	  p->current_lap().avg_speed = parse_double(*p->_characters);
	  break;
	case state::LAP_MAX_SPEED:
	  p->current_lap().max_speed = parse_double(*p->_characters);
	  break;
	case state::LAP_CALORIES:
	  p->current_lap().total_calories = parse_double(*p->_characters);
	  break;
	case state::TP_TIME:
	  p->current_point().timestamp = parse_time(*p->_characters);
	  break;
	case state::TP_LAT:
	  p->current_point().location.latitude = parse_double(*p->_characters);
	  p->destination().set_has_location(true);
	  break;
	case state::TP_LONG:
	  p->current_point().location.longitude = parse_double(*p->_characters);
	  p->destination().set_has_location(true);
	  break;
	case state::TP_ALTITUDE:
	  p->current_point().altitude = parse_double(*p->_characters);
	  p->destination().set_has_altitude(true);
	  break;
	case state::TP_DISTANCE:
	  p->current_point().distance = parse_double(*p->_characters);
	  break;
	case state::TP_SPEED:
	  p->current_point().speed = parse_double(*p->_characters);
	  p->destination().set_has_speed(true);
	  break;
	case state::VALUE: {
	  double x = parse_double(*p->_characters);
	  switch (p->previous_state())
	    {
	    case state::LAP_AVG_HEART_RATE:
	      p->current_lap().avg_heart_rate = x;
	      break;
	    case state::LAP_MAX_HEART_RATE:
	      p->current_lap().max_heart_rate = x;
	      break;
	    case state::TP_HEART_RATE:
	      p->current_point().heart_rate = x;
	      p->destination().set_has_heart_rate(true);
	      break;
	    default:
	      break;
	    }
	  break; }
	default:
	  break;
	}
    }

  p->pop_state ();

  if (p->_characters)
    delete p->_characters, p->_characters = nullptr;
}

void
tcx_parser::sax_warning(void *ctx, const char *msg, ...)
{
#if LOG_ERRORS
  fputs("XML warning: ", stderr);
  va_list args;
  va_start(args, msg);
  vfprintf(stderr, msg, args);
  va_end(args);
#endif
}

void
tcx_parser::sax_error(void *ctx, const char *msg, ...)
{
  tcx_parser *p = static_cast<tcx_parser *>(ctx);

  p->set_error ();

#if LOG_ERRORS
  fputs("XML error: ", stderr);
  va_list args;
  va_start(args, msg);
  vfprintf(stderr, msg, args);
  va_end(args);
#endif
}

} // namespace gps
} // namespace act
