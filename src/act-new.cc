// -*- c-style: gnu -*-

#include "act-config.h"

#include <getopt.h>

enum long_option_codes
{
  opt_edit = 256,
  opt_activity,
  opt_type,
  opt_course,
  opt_keywords,
  opt_equipment,
  opt_distance,
  opt_duration,
  opt_pace,
  opt_speed,
  opt_max_pace,
  opt_max_speed,
  opt_resting_hr,
  opt_average_hr,
  opt_max_hr,
  opt_calories,
  opt_weight,
  opt_temperature,
  opt_weather,
  opt_quality,
  opt_effort,
  opt_fit_file,
  opt_tcx_file,
  opt_field,
};

static const struct option long_options[] =
{
  {"edit", no_argument, 0, opt_edit},
  {"activity", required_argument, 0, opt_activity},
  {"type", required_argument, 0, opt_type},
  {"course", required_argument, 0, opt_course},
  {"keywords", required_argument, 0, opt_keywords},
  {"equipment", required_argument, 0, opt_equipment},
  {"distance", required_argument, 0, opt_distance},
  {"duration", required_argument, 0, opt_duration},
  {"pace", required_argument, 0, opt_pace},
  {"speed", required_argument, 0, opt_speed},
  {"max-pace", required_argument, 0, opt_max_pace},
  {"max-speed", required_argument, 0, opt_max_speed},
  {"resting-hr", required_argument, 0, opt_resting_hr},
  {"average-hr", required_argument, 0, opt_average_hr},
  {"max-hr", required_argument, 0, opt_max_hr},
  {"calories", required_argument, 0, opt_calories},
  {"weight", required_argument, 0, opt_weight},
  {"temperature", required_argument, 0, opt_temperature},
  {"weather", required_argument, 0, opt_weather},
  {"quality", required_argument, 0, opt_quality},
  {"effort", required_argument, 0, opt_effort},
  {"fit-file", required_argument, 0, opt_fit_file},
  {"tcx-file", required_argument, 0, opt_tcx_file},
  {"field", required_argument, 0, opt_field},
};

int
act_new_main(int argc, const char **argv)
{
  const char *prog_name = argv[0];

}
