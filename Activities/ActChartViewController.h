// -*- c-style: gnu -*-

#import "ActViewController.h"

#import "act-gps-chart.h"

#import <memory>

@class ActChartView, ActChartViewConfigLabel;

@interface ActChartViewController : ActViewController
{
  IBOutlet ActChartView *_chartView;
  IBOutlet ActChartViewConfigLabel *_configButton;
  IBOutlet NSMenu *_configMenu;

  uint32_t _fieldMask;

  std::unique_ptr<act::gps::chart> _chart;
  std::unique_ptr<act::gps::activity> _smoothed_data;
}

- (IBAction)controlAction:(id)sender;
- (IBAction)configMenuAction:(id)sender;

- (IBAction)toggleChartField:(id)sender;
- (BOOL)chartFieldIsShown:(NSInteger)field;

@end


@interface ActChartView : NSView
{
  IBOutlet ActChartViewController *_controller;
}
@end


@interface ActChartViewConfigLabel : NSTextField
{
  IBOutlet ActChartViewController *_controller;
}
@end
