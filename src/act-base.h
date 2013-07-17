/* -*- c-style: gnu -*- */

#ifndef ACT_BASE_H
#define ACT_BASE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>

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

#undef MAX
#define MAX(x,y) ((x) > (y) ? (x) : (y))

#undef MIN
#define MIN(x,y) ((x) < (y) ? (x) : (y))

#ifdef __cplusplus

namespace act {

struct uncopyable
{
  uncopyable() = default;
  explicit uncopyable(const uncopyable &rhs) = delete;
  uncopyable &operator=(const uncopyable &rhs) = delete;
};

} // namespace act

#endif /* __cplusplus */
#endif /* ACT_BASE_H */
