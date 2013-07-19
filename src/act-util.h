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

// misc functions

bool string_has_suffix(const std::string &str, const char *suffix);

void trim_newline_characters(char *ptr);

// Modifies 'file' to be absolute if the named file is found.

bool find_file_under_directory(std::string &file, const char *dir);

// Ignores common garbage file names, e.g ".*" and "*~"

void map_directory_files(const char *dir,
  void (*fun) (const char *path, void *ctx), void *ctx);

bool make_path(const char *path);

bool path_has_extension(const char *path, const char *ext);

} // namespace act

#endif /* ACT_UTIL_H */
