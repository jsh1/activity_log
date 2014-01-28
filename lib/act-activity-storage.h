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

#ifndef ACT_ACTIVITY_STORAGE_H
#define ACT_ACTIVITY_STORAGE_H

#include "act-base.h"

#include <memory>
#include <string>
#include <vector>

namespace act {

class activity_storage : public uncopyable
{
  // Using a vector here to preserve ordering. Could add a map of
  // some sort later if we need faster lookups.

  typedef std::vector<std::pair<std::string, std::string>> field_map;

  uint32_t _seed;

  std::string _path;
  mutable uint32_t _path_seed;

  field_map _header;
  std::string _body;

  int field_index(const char *name) const;

public:
  activity_storage();
  activity_storage(const activity_storage &rhs);

  // only copies the contents, not the seeds and path.

  activity_storage &operator= (const activity_storage &rhs);

  uint32_t seed() const;
  void increment_seed();

  void set_path(const char *path);
  const char *path() const;

  uint32_t path_seed() const;
  void set_path_seed(uint32_t seed);

  bool read_file(const char *path);
  bool write_file(const char *path) const;

  bool needs_synchronize() const;
  void synchronize_file() const;

  void canonicalize_field_order();

  std::string &body();
  const std::string &body() const;

  size_t field_count() const;
  const std::string &field_name(size_t idx) const;
  const std::string &field_value(size_t idx) const;

  std::string &operator[] (const char *name);
  std::string &operator[] (const std::string &name);

  const std::string *field_ptr(const char *name) const;
  const std::string *field_ptr(const std::string &name) const;

  bool delete_field(const char *name);
  bool delete_field(const std::string &name);

  bool set_field_name(const std::string &old_name, const std::string
    &new_name);

  bool field_read_only_p(const char *name) const;

  typedef field_map::iterator iterator;
  typedef field_map::const_iterator const_iterator;
  typedef field_map::value_type value_type;
  typedef field_map::reference reference;
  typedef field_map::const_reference const_reference;
  
  iterator begin();
  iterator end();
  const_iterator begin() const;
  const_iterator end() const;
};

typedef std::shared_ptr<activity_storage> activity_storage_ref;
typedef std::shared_ptr<const activity_storage> const_activity_storage_ref;

// implementation details

inline const char *
activity_storage::path() const
{
  return _path.c_str();
}

inline uint32_t
activity_storage::seed() const
{
  return _seed;
}

inline void
activity_storage::increment_seed()
{
  _seed++;
}

inline uint32_t
activity_storage::path_seed() const
{
  return _path_seed;
}

inline void
activity_storage::set_path_seed(uint32_t seed)
{
  _path_seed = seed;
}

inline bool
activity_storage::needs_synchronize() const
{
  return _path.size() != 0 && _path_seed != _seed;
}

inline const std::string &
activity_storage::body() const
{
  return _body;
}

inline std::string &
activity_storage::body()
{
  return _body;
}

inline size_t
activity_storage::field_count() const
{
  return _header.size();
}

inline const std::string &
activity_storage::field_name(size_t idx) const
{
  return _header[idx].first;
}

inline const std::string &
activity_storage::field_value(size_t idx) const
{
  return _header[idx].second;
}

inline std::string &
activity_storage::operator[](const std::string &name)
{
  return operator[] (name.c_str());
}

inline const std::string *
activity_storage::field_ptr(const std::string &name) const
{
  return field_ptr(name.c_str());
}

inline bool
activity_storage::delete_field(const std::string &name)
{
  return delete_field(name.c_str());
}

inline activity_storage::iterator
activity_storage::begin()
{
  return _header.begin();
}

inline activity_storage::iterator
activity_storage::end()
{
  return _header.end();
}

inline activity_storage::const_iterator
activity_storage::begin() const
{
  return _header.begin();
}

inline activity_storage::const_iterator
activity_storage::end() const
{
  return _header.end();
}

} // namespace act

#endif /* ACT_ACTIVITY_STORAGE_H */
