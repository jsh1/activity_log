// -*- c-style: gnu -*-

#import "ActViewController.h"

#import "objc-ptr.h"

#import "act-activity.h"

#import <memory>

@class ActNotesListView, ActNotesHeaderView;

struct ActNotesItem
{
  act::activity_storage_ref storage;

  mutable std::unique_ptr<act::activity> activity;

  mutable time_t date;
  mutable int year;
  mutable int month;
  mutable int week;
  mutable int day_of_week;
  mutable int day_of_month;

  mutable objc_ptr<NSString> body;

  mutable CGFloat body_width;
  mutable CGFloat body_height;
  mutable CGFloat height;

  mutable bool valid_date :1;
  mutable bool valid_height :1;

  ActNotesItem();
  explicit ActNotesItem(act::activity_storage_ref storage);
  explicit ActNotesItem(const ActNotesItem &rhs);

  struct header_stats
    {
      double month_distance;
      double week_distance;
    };

  void draw(const NSRect &bounds, uint32_t flags) const;
  void draw_header(const NSRect &bounds, uint32_t flags,
    const header_stats &stats) const;

  void update_date() const;
  void update_body() const;
  void update_body_height(CGFloat width) const;
  void update_height(CGFloat width) const;

  double distance() const;
  double duration() const;
  double points() const;

  bool same_day_p(const ActNotesItem &other) const;

private:
  static bool initialized;
  static NSDictionary *title_attrs;
  static NSDictionary *selected_title_attrs;
  static NSDictionary *body_attrs;
  static NSDictionary *time_attrs;
  static NSDictionary *stats_attrs;
  static NSDictionary *dow_attrs;
  static NSDictionary *dom_attrs;
  static NSDictionary *month_attrs;
  static NSDictionary *week_attrs;
  static NSDictionary *header_stats_attrs;
  static NSColor *separator_color;
  static NSDateFormatter *time_formatter;
  static NSDateFormatter *week_formatter;
  static NSDateFormatter *month_formatter;

  static void initialize();
};

@interface ActNotesListViewController : ActViewController
{
  IBOutlet NSScrollView *_scrollView;
  IBOutlet ActNotesListView *_listView;
  IBOutlet ActNotesHeaderView *_headerView;

  std::vector<ActNotesItem> _activities;

  NSInteger _headerItemIndex;
  struct ActNotesItem::header_stats _headerStats;
}

@property(nonatomic, readonly) const std::vector<ActNotesItem> &activities;

@end

@interface ActNotesListView : NSView
{
  IBOutlet ActNotesListViewController *_controller;
}
@end

@interface ActNotesHeaderView : NSView
{
  IBOutlet ActNotesListViewController *_controller;
}
@end
