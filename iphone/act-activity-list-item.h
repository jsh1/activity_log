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

#import <UIKit/UIKit.h>

#import "act-activity.h"

namespace act {

struct activity_list_item
{
  std::unique_ptr<activity> activity;

  NSString *body;

  CGFloat body_width;
  CGFloat body_height;
  CGFloat height;
  bool valid_height;

  explicit activity_list_item(act::activity_storage_ref storage);
  explicit activity_list_item(const activity_list_item &rhs);

  void draw(const CGRect &bounds);

  void update_body();
  void update_body_height(CGFloat width);
  void update_height(CGFloat width);

private:
  activity_list_item();

  static bool initialized;
  static NSDictionary *title_attrs;
  static NSDictionary *body_attrs;
  static NSDictionary *time_attrs;
  static NSDictionary *stats_attrs;
  static NSDateFormatter *time_formatter;

  static void initialize();
};

typedef std::shared_ptr<activity_list_item> activity_list_item_ref;

} // namespace act
