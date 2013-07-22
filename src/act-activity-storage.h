// -*- c-style: gnu -*-

#ifndef ACT_ACTIVITY_STORAGE_H
#define ACT_ACTIVITY_STORAGE_H

#include "act-base.h"

#include <string>
#include <vector>

namespace act {

class activity_storage
{
  // Using a vector here to preserve ordering. Could add a map of
  // some sort later if we need faster lookups.

  typedef std::vector<std::pair<std::string, std::string>> field_map;

  field_map _header;
  std::string _body;

  int field_index(const char *name) const;

public:
  bool read_file(const char *path);
  bool write_file(const char *path) const;

  void canonicalize_field_order();

  std::string &body();
  const std::string &body() const;

  std::string &operator[] (const char *name);
  std::string &operator[] (const std::string &name);

  const std::string *field_ptr(const char *name) const;
  const std::string *field_ptr(const std::string &name) const;

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

// implementation details

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
