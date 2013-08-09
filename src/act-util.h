/* -*- c-style: gnu -*- */

#ifndef ACT_UTIL_H
#define ACT_UTIL_H

#include "act-base.h"

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

  T &operator[](int i) {return _ptr[i];}
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
