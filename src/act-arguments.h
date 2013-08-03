// -*- c-style: gnu -*-

#ifndef ACT_ARGUMENTS_H
#define ACT_ARGUMENTS_H

#include "act-base.h"
#include "act-types.h"

#include <string>
#include <vector>

namespace act {

class arguments
{
  const char *_program_name;
  std::vector<const char *> _args;
  std::vector<char *> _allocations;
  ptrdiff_t _short_opt_offset;
  bool _getopt_finished;

public:
  arguments(int argc, const char **argv);
  arguments(const arguments &rhs);
  ~arguments();

  const char *program_name() const;

  const std::vector<const char *> args() const;

  const char *const *argv() const;
  int argc() const;

  bool program_name_p(const char *name) const;

  void push_back(const char *arg);
  void push_back(const std::string &arg);

  struct option
    {
      int option_id;
      const char *long_option;
      const char short_option;
      const char *arg_name;
      const char *desc;
    };

  enum
    {
      opt_eof = -1,
      opt_error = -2,
    };

  enum
    {
      opt_partial = 1U << 0,
    };

  int getopt(const struct option *opts, const char **arg_ptr,
    uint32_t flags = 0);

  bool make_date_range(std::vector<date_range> &dates);

  static void print_options(const struct option *opts, FILE *fh);
};

// implementation

inline const char *
arguments::program_name() const
{
  return _program_name;
}

inline const std::vector<const char *>
arguments::args() const
{
  return _args;
}

inline const char *const *
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
arguments::push_back(const std::string &arg)
{
  push_back(arg.c_str());
}

} // namespace act

#endif /* ACT_ARGUMENTS_H */
