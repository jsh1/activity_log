// -*- c-style: gnu -*-

#include "act-activity-storage.h"

#include "act-config.h"
#include "act-util.h"

#include <xlocale.h>

namespace act {

bool
activity_storage::read_file(const char *path)
{
  FILE *fh = fopen(path, "r");
  if (!fh)
    return false;

  _header.clear();
  _body.clear();

  std::string *last_value = nullptr;

  /* Using normal email-header rules: first empty line completes header
     section, and leading whitespace can be used to append a line onto
     the previous header. */

  char buf[4096];
  while (fgets(buf, sizeof(buf), fh))
    {
      if (buf[0] == '\n')
	break;

      if (_header.size() == 0 || !isspace_l(buf[0], nullptr))
	{
	  char *ptr = strchr(buf, ':');
	  if (!ptr)
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

  while (fgets(buf, sizeof(buf), fh))
    _body.append(buf);

  fclose(fh);
  return true;
}

bool
activity_storage::write_file(const char *path) const
{
  FILE *fh = fopen(path, "w");
  if (!fh)
    return false;

  for (const auto &it : _header)
    fprintf(fh, "%s: %s\n", it.first.c_str(), it.second.c_str());

  fputs("\n", fh);

  fputs(_body.c_str(), fh);

  fclose(fh);
  return true;
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
    }

  return _header[idx].second;
}

const std::string *
activity_storage::field_ptr(const char *name) const
{
  int idx = field_index(name);
  return idx >= 0 ? &_header[idx].second : nullptr;
}

} // namespace act
