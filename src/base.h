/* -*- c-style: gnu -*- */

#ifndef BASE_H
#define BASE_H

#include <stdint.h>
#include <stdbool.h>

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

#endif /* BASE_H */
