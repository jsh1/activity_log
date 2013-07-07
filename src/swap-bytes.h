// -*- c-style: gnu -*-

#ifndef SWAP_BYTES_H
#define SWAP_BYTES_H

#include "base.h"

#if defined(__APPLE__) && __APPLE__
# include <libkern/OSByteOrder.h>
#endif

namespace activity_log {

namespace swap_bytes {

inline uint16_t
swap_bytes_16(uint16_t value)
{
#if defined(__APPLE__) && __APPLE__
  return OSSwapInt16(value);
#else
  return (value << 8) | (value >> 8);
#endif
}

inline uint32_t
swap_bytes_32(uint32_t value)
{
#if defined(__APPLE__) && __APPLE__
  return OSSwapInt32(value);
#else
  return ((value >> 24) | ((value & 0x00ff0000U) >> 8)
	  | ((value & 0x0000ff00U) << 8) | (value << 24));
#endif
}

template<typename T> struct int_traits {};

template<> struct int_traits<int8_t>
{
  static int8_t swap_bytes(int8_t x) {return x;}
};

template<> struct int_traits<uint8_t>
{
  static uint8_t swap_bytes(uint8_t x) {return x;}
};

template<> struct int_traits<int16_t>
{
  static int16_t swap_bytes(int16_t x) {return swap_bytes_16(x);}
};

template<> struct int_traits<uint16_t>
{
  static uint16_t swap_bytes(uint16_t x) {return swap_bytes_16(x);}
};

template<> struct int_traits<int32_t>
{
  static int32_t swap_bytes(int32_t x) {return swap_bytes_32(x);}
};

template<> struct int_traits<uint32_t>
{
  static uint32_t swap_bytes(uint32_t x) {return swap_bytes_32(x);}
};

} // namespace swap_bytes

#if __BYTE_ORDER == __LITTLE_ENDIAN

template<typename T> inline T
swap_little_to_host(T x)
{
  return x;
}

template<typename T> inline T
swap_big_to_host(T x)
{
  return swap_bytes::int_traits<T>::swap_bytes(x);
}

template<typename T> inline T
swap_host_to_little(T x)
{
  return x;
}

template<typename T> inline T
swap_host_to_big(T x)
{
  return swap_bytes::int_traits<T>::swap_bytes(x);
}

#elif __BYTE_ORDER == __BIG_ENDIAN

template<typename T> inline T
swap_little_to_host(T x)
{
  return swap_bytes::int_traits<T>::swap_bytes(x);
}

template<typename T> inline T
swap_big_to_host(T x)
{
  return x;
}

template<typename T> inline T
swap_host_to_little(T x)
{
  return swap_bytes::int_traits<T>::swap_bytes(x);
}

template<typename T> inline T
swap_host_to_big(T x)
{
  return x;
}

#else

# error "Unknown endianness"

#endif

} // namespace activity_log

#endif /* SWAP_BYTES */
