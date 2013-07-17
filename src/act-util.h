/* -*- c-style: gnu -*- */

#ifndef ACT_UTIL_H
#define ACT_UTIL_H

#include "act-base.h"

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

} // namespace act

#endif /* ACT_UTIL_H */
