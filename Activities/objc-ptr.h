// -*- c-style: gnu -*-

#ifndef OBJC_PTR_H
#define OBJC_PTR_H

#include <Foundation/NSObject.h>

template<typename T>
class objc_ptr
{
  T *_p;

public:
  objc_ptr();

  explicit objc_ptr(T *p);
  objc_ptr(const objc_ptr &rhs);

  template<typename U> explicit objc_ptr(U *p);
  template<typename U> objc_ptr(const objc_ptr<U> &rhs);

  ~objc_ptr();

  void reset();
  void reset(T *p);

  objc_ptr &operator=(T *p);
  objc_ptr &operator=(const objc_ptr<T> &p);

  T *get() const;
  T *operator->() const;

  operator bool() const;
  bool operator!() const;
  bool operator==(T *p) const;
  bool operator!=(T *p) const;
  bool operator==(const objc_ptr<T> &p) const;
  bool operator!=(const objc_ptr<T> &p) const;
};

// implementation details

template<typename T> inline
objc_ptr<T>::objc_ptr()
: _p(nil)
{
}

template<typename T> inline
objc_ptr<T>::objc_ptr(T *p)
: _p(p)
{
}

template<typename T> inline
objc_ptr<T>::objc_ptr(const objc_ptr &p)
: _p([p._p retain])
{
}

template<typename T> template<typename U> inline
objc_ptr<T>::objc_ptr(U *p)
: _p(p)
{
}

template<typename T> template<typename U> inline
objc_ptr<T>::objc_ptr(const objc_ptr<U> &p)
: _p([p._p retain])
{
}

template<typename T> inline
objc_ptr<T>::~objc_ptr()
{
  [_p release];
}

template<typename T> inline void
objc_ptr<T>::reset()
{
  [_p release];
  _p = nil;
}

template<typename T> inline void
objc_ptr<T>::reset(T *p)
{
  [_p release];
  _p = p;
}

template<typename T> inline objc_ptr<T> &
objc_ptr<T>::operator=(T *p)
{
  if (_p != p)
    {
      [_p release];
      _p = [p retain];
    }
  return *this;
}

template<typename T> inline objc_ptr<T> &
objc_ptr<T>::operator=(const objc_ptr<T> &p)
{
  if (_p != p._p)
    {
      [_p release];
      _p = [p._p retain];
    }
  return *this;
}

template<typename T> inline T *
objc_ptr<T>::get() const
{
  return _p;
}

template<typename T> inline T *
objc_ptr<T>::operator->() const
{
  return _p;
}

template<typename T> inline
objc_ptr<T>::operator bool() const
{
  return _p != nil;
}

template<typename T> inline bool
objc_ptr<T>::operator!() const
{
  return _p == nil;
}

template<typename T> inline bool
objc_ptr<T>::operator==(T *p) const
{
  return _p == p;
}

template<typename T> inline bool
objc_ptr<T>::operator!=(T *p) const
{
  return _p != p;
}

template<typename T> inline bool
objc_ptr<T>::operator==(const objc_ptr<T> &p) const
{
  return _p == p._p;
}

template<typename T> inline bool
objc_ptr<T>::operator!=(const objc_ptr<T> &p) const
{
  return _p != p._p;
}

#endif /* OBJC_PTR_H */
