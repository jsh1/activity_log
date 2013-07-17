// -*- c-style: gnu -*-

#ifndef ACT_ARGUMENTS_H
#define ACT_ARGUMENTS_H

#include "base.h"

#include <vector>

namespace activity_log {

class arguments
{
  const char *_program_name;
  std::vector<const char *> _args;
  std::vector<char *> _allocations;
  bool _getopt_finished;

public:
  arguments(int argc, const char **argv);
  arguments(const arguments &rhs);
  ~arguments();

  const char *program_name() const;
  const char **argv() const;
  int argc() const;

  bool program_name_p(const char *name) const;

  void push_back(const char *arg);
  void push_back(const std::string &arg);

  struct option
    {
      int option_id;
      const char *long_option;
      const char short_option;
      bool has_arg;
    };

  enum
    {
      opt_eof = -1;
      opt_error = -2;
    };

  int getopt(const struct option *opts, const char **arg_ptr);
};

// implementation

inline const char *
arguments::program_name() const
{
  return _program_name;
}

inline const char **
arguments::argv() const
{
  return &_args[0];
}

inline int
arguments::argc() const
{
  return _args.size();
}

inline void
arguments::append(const std::string &arg)
{
  push_back(arg.c_str());
}

} // namespace activity_log

#endif /* ACT_ARGUMENTS_H */
