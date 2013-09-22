// -*- c-style: gnu -*-

#include "act-new.h"

using namespace act;

int
main(int argc, const char **argv)
{
  arguments args(argc, argv);

  if (args.program_name_p("act-import"))
    return act_import(args);
  else
    return act_new(args);
}
