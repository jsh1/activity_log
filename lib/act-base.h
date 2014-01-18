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

#ifndef ACT_BASE_H
#define ACT_BASE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
#include <limits.h>

#if defined(__APPLE__) && __APPLE__
# include <Availability.h>
# include <TargetConditionals.h>
#endif

#ifndef __BIG_ENDIAN
# define __BIG_ENDIAN 0x1234
#endif
#ifndef __LITTLE_ENDIAN
# define __LITTLE_ENDIAN 0x4321
#endif
#ifndef __BYTE_ORDER
# if __LITTLE_ENDIAN__
#  define __BYTE_ORDER __LITTLE_ENDIAN
# elif __BIG_ENDIAN__
#  define __BYTE_ORDER __BIG_ENDIAN
# else
#  error "Unknown endianness"
# endif
#endif

#ifdef __cplusplus

namespace act {

struct uncopyable
{
  uncopyable() = default;
  explicit uncopyable(const uncopyable &rhs) = delete;
  uncopyable &operator=(const uncopyable &rhs) = delete;
};

inline void
mix(double &a, const double &b, const double &c, double f)
{
  a = b + (c - b) * f;
}

inline void
mix(float &a, const float &b, const float &c, double f)
{
  a = b + (c - b) * f;
}

} // namespace act

#endif /* __cplusplus */
#endif /* ACT_BASE_H */
