// -*- c-style: gnu -*-

#include "act-activity-storage.h"

#include "act-config.h"
#include "act-util.h"

#include <xlocale.h>

namespace act {

activity_storage::activity_storage()
: _seed(0),
  _path_seed(0)
{
}

activity_storage::activity_storage(const activity_storage &rhs)
: _seed(rhs._seed),
  _path(rhs._path),
  _path_seed(rhs._path_seed),
  _header(rhs._header),
  _body(rhs._body)
{
}

void
activity_storage::set_path(const char *path)
{
  _path = path;
  _path_seed = _seed;
}

bool
activity_storage::read_file(const char *path)
{
  FILE_ptr fh(fopen(path, "r"));
  if (!fh)
    return false;

  _header.clear();
  _body.clear();

  std::string *last_value = nullptr;

  /* Using normal email-header rules: first empty line completes header
     section, and leading whitespace can be used to append a line onto
     the previous header. */

  char buf[4096];
  while (fgets(buf, sizeof(buf), fh.get()))
    {
      if (buf[0] == '\n')
	break;

      if (_header.size() == 0 || !isspace_l(buf[0], nullptr))
	{
	  char *ptr = strchr(buf, ':');
	  if (ptr == nullptr)
	    continue;

	  *ptr++ = 0;

	  last_value = &(*this)[buf];

	  while (*ptr && isspace_l(*ptr, nullptr))
	    ptr++;

	  trim_newline_characters(ptr);
	  *last_value = ptr;
	}
      else
	{
	  trim_newline_characters(buf);
	  if (last_value != nullptr)
	    last_value->append(buf);
	}
    }

  while (fgets(buf, sizeof(buf), fh.get()))
    _body.append(buf);

  increment_seed();

  return true;
}

bool
activity_storage::write_file(const char *path) const
{
  FILE_ptr fh(fopen(path, "w"));
  if (!fh)
    return false;

  for (const auto &it : _header)
    fprintf(fh.get(), "%s: %s\n", it.first.c_str(), it.second.c_str());

  fputs("\n", fh.get());

  fputs(_body.c_str(), fh.get());

  return true;
}

void
activity_storage::synchronize_file() const
{
  if (_path.size() == 0 || _path_seed == _seed)
    return;

  if (!write_file(_path.c_str()))
    return;

  _path_seed = _seed;
}

void
activity_storage::canonicalize_field_order()
{
  std::stable_sort(_header.begin(), _header.end(),
		   [] (const value_type &a, const value_type &b) -> bool {
		     field_id a_id = lookup_field_id(a.first.c_str());
		     field_id b_id = lookup_field_id(b.first.c_str());
		     return a_id < b_id;
		   });
}

int
activity_storage::field_index(const char *name) const
{
  for (const auto &it : _header)
    {
      if (strcasecmp_l(it.first.c_str(), name, nullptr) == 0)
	return &it - &_header[0];
    }

  return -1;
}

std::string &
activity_storage::operator[](const char *name)
{
  int idx = field_index(name);

  if (idx < 0)
    {
      idx = _header.size();
      _header.resize(idx+1);
      _header[idx].first = name;
      increment_seed();
    }

  return _header[idx].second;
}

const std::string *
activity_storage::field_ptr(const char *name) const
{
  int idx = field_index(name);
  return idx >= 0 ? &_header[idx].second : nullptr;
}

bool
activity_storage::delete_field(const char *name)
{
  int idx = field_index(name);
  if (idx < 0)
    return false;

  _header.erase(_header.begin() + idx);
  increment_seed();

  return true;
}

bool
activity_storage::set_field_name(const std::string &old_name,
				 const std::string &new_name)
{
  int idx = field_index(old_name.c_str());

  if (idx < 0)
    return false;

  _header[idx].first = new_name;
  increment_seed();

  return true;
}

bool
activity_storage::field_read_only_p(const char *name) const
{
  field_id id = lookup_field_id(name);

  if (act::field_read_only_p(id))
    return true;

  switch (id)
    {
    case field_id::pace:
    case field_id::speed:
      if (field_ptr("pace") == nullptr
	  && field_ptr("speed") == nullptr
	  && field_ptr("duration") != nullptr
	  && field_ptr("distance") != nullptr)
	return true;
      break;

    case field_id::distance:
      if (field_ptr("distance") == nullptr
	  && field_ptr("duration") != nullptr
	  && (field_ptr("speed") != nullptr
	      || field_ptr("pace") != nullptr))
	return true;
      break;

    case field_id::duration:
      if (field_ptr("duration") == nullptr
	  && field_ptr("distance") != nullptr
	  && (field_ptr("speed") != nullptr
	      || field_ptr("pace") != nullptr))
	return true;
      break;

    default:
      break;
    }

  return false;
}

} // namespace act
