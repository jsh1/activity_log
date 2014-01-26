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

#import "act-activity-list-section.h"

#import "act-config.h"
#import "act-format.h"

#import "ActColor.h"

namespace act {

bool activity_list_section::initialized;
NSDateFormatter *activity_list_section::date_formatter;

void
activity_list_section::initialize()
{
  date_formatter = [[NSDateFormatter alloc] init];
  [date_formatter setDateFormat:
   [NSDateFormatter dateFormatFromTemplate:@"MMMMYYYY" options:0 locale:nil]];

  initialized = true;
}

activity_list_section::activity_list_section(time_t date)
: date(date)
{
}

activity_list_section::activity_list_section(const activity_list_section &rhs)
: date(rhs.date),
  items(rhs.items)
{
}

void
activity_list_section::configure_view(UITableViewHeaderFooterView *view)
{
  if (!initialized)
    initialize();

  UILabel *label = view.textLabel;

  label.text = [date_formatter stringFromDate:
		[NSDate dateWithTimeIntervalSince1970:date]];
}

} // namespace act
