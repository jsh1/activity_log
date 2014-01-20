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
  explicit arguments(const char *program_name);
  arguments(int argc, const char **argv);
  arguments(const arguments &rhs);
  ~arguments();

  const char *program_name() const;

  const std::vector<const char *> args() const;

  const char *const *argv() const;
  size_t argc() const;

  bool program_name_p(const char *name) const;

  void push_front(const char *arg);
  void push_front(const std::string &arg);

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

inline size_t
arguments::argc() const
{
  return _args.size();
}

inline void
arguments::push_front(const std::string &arg)
{
  push_front(arg.c_str());
}

inline void
arguments::push_back(const std::string &arg)
{
  push_back(arg.c_str());
}

} // namespace act

#endif /* ACT_ARGUMENTS_H */
