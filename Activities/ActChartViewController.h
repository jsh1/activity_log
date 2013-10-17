// -*- c-style: gnu -*-

#import "ActViewController.h"

#import "act-gps-chart.h"

#import <memory>

@class ActChartView;

@interface ActChartViewController : ActViewController
{
  IBOutlet ActChartView *_chartView;
  IBOutlet NSSegmentedControl *_segmentedControl;

  std::unique_ptr<act::gps::chart> _chart;
  std::unique_ptr<act::gps::activity> _smoothed_data;
}

- (IBAction)controlAction:(id)sender;

- (IBAction)toggleChartField:(id)sender;
- (BOOL)chartFieldIsShown:(NSInteger)field;

@end


@interface ActChartView : NSView
{
  IBOutlet ActChartViewController *_controller;
}
@end