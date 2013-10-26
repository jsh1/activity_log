// -*- c-style: gnu -*-

#import "ActViewController.h"

#import "act-gps-chart.h"

#import <memory>

@class ActChartView, ActChartViewConfigLabel;

namespace chart_view {
  class chart;
}

@interface ActChartViewController : ActViewController
{
  IBOutlet ActChartView *_chartView;
  IBOutlet ActChartViewConfigLabel *_configButton;
  IBOutlet NSMenu *_configMenu;

  uint32_t _fieldMask;

  std::unique_ptr<chart_view::chart> _chart;
  std::unique_ptr<act::gps::activity> _smoothed_data;
}

- (IBAction)configMenuAction:(id)sender;

- (IBAction)toggleChartField:(id)sender;
- (BOOL)chartFieldIsShown:(NSInteger)field;

@end


@interface ActChartView : NSView
{
  IBOutlet ActChartViewController *_controller;

  NSTrackingArea *_trackingArea;
}
@end


@interface ActChartViewConfigLabel : NSTextField
{
  IBOutlet ActChartViewController *_controller;
}
@end
