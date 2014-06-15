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

#ifndef ACT_UTIL_H
#define ACT_UTIL_H

#include "act-base.h"

#include <dirent.h>
#include <stdio.h>
#include <string>

namespace act {

template<typename T>
class malloc_ptr
{
  T *_ptr;

public:
  explicit malloc_ptr(size_t size) : _ptr((T*)malloc(sizeof(T) * size)) {}
  ~malloc_ptr() {free(_ptr);}

  T get() {return _ptr;}

  T &operator[](ptrdiff_t i) {return _ptr[i];}
  T *operator->() {return _ptr;}
  T &operator*() {return *_ptr;}

  operator bool() const {return _ptr != 0;}

private:
  explicit malloc_ptr(const malloc_ptr &rhs);
  malloc_ptr &operator=(const malloc_ptr &rhs);
};

struct case_insensitive_string_hash
{
  size_t operator() (const std::string &name) const;
  size_t operator() (const char *name) const;
};

struct case_insensitive_string_pred
{
  bool operator() (const std::string &a, const std::string &b) const;
  bool operator() (const char *a, const char *b) const;
};

struct case_insensitive_string_compare
{
  bool operator() (const std::string &a, const std::string &b) const;
  bool operator() (const char *a, const char *b) const;
};

class FILE_ptr
{
  FILE *fh;

public:
  explicit FILE_ptr(FILE *f) : fh(f) {}
  ~FILE_ptr() {if (fh != nullptr) fclose(fh);}

  operator bool() const {return fh != nullptr;}
  bool operator!() const {return fh == nullptr;}

  FILE *get() const {return fh;}
};

class DIR_ptr
{
  DIR *dir;

public:
  explicit DIR_ptr(DIR *d) : dir(d) {}
  ~DIR_ptr() {if (dir != nullptr) closedir(dir);}

  operator bool() const {return dir != nullptr;}
  bool operator!() const {return dir == nullptr;}

  DIR *get() const {return dir;}
};

class output_pipe
{
  const char *_program_path;
  const char *const *_program_argv;
  pid_t _child_pid;
  int _output_fd;

public:
  output_pipe(const char *program_path, const char *const program_argv[]);
  ~output_pipe();

  bool start();
  bool finish();

  FILE *open_output(const char *mode);
};

// misc functions

bool string_has_suffix(const std::string &str, const char *suffix);

void trim_newline_characters(char *ptr);

void print_indented_string(const char *str, size_t len, FILE *fh);

unsigned int convert_hexdigit(int c);

bool matches_word_list(const char *str, const char *lst);

// Modifies 'file' to be absolute if the named file is found.

bool find_file_under_directory(std::string &file, const char *dir);

// Ignores common garbage file names, e.g ".*" and "*~"

void map_directory_files(const char *dir,
  void (*fun) (const char *path, void *ctx), void *ctx);

void cat_file(const char *src);

bool make_path(const char *path);

bool path_has_extension(const char *path, const char *ext);

void tilde_expand_file_name(std::string &str);
void tilde_expand_file_name(std::string &dest, const char *src);

// misc date utility functions

void standardize_month(int &year, int &month);

bool leap_year_p(int year);

time_t seconds_in_year(int year);
time_t seconds_in_month(int year, int month);

time_t timezone_offset();

// returns number of days or seconds since Jan 1 1970. Year is
// absolute, month is 0..11, day is 1..31.

unsigned int make_day(unsigned int year, unsigned int month, unsigned int day);
time_t make_time(unsigned int year, unsigned int month, unsigned int day);

time_t year_time(int year);
time_t month_time(int year, int month);

int week_index(time_t date);
time_t week_date(int week_index);

int day_of_week_index(const char *str);
int month_index(const char *str);

// general utility functions

int popcount(uint32_t x);

// implementation details

inline size_t
case_insensitive_string_hash::operator() (const std::string &name) const
{
  return operator() (name.c_str());
}

inline bool
case_insensitive_string_pred::operator() (const std::string &a,
					  const std::string &b) const
{
  if (a.size() != b.size())
    return false;
  else
    return operator() (a.c_str(), b.c_str());
}

inline bool
case_insensitive_string_compare::operator() (const std::string &a,
					     const std::string &b) const
{
  return operator() (a.c_str(), b.c_str());
}

} // namespace act

#endif /* ACT_UTIL_H */
