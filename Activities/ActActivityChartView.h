// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

#import "act-gps-chart.h"

#import <memory>

@interface ActActivityChartView : ActActivitySubview
{
  IBOutlet NSSegmentedControl *_segmentedControl;

  std::unique_ptr<act::gps::chart> _chart;
  std::unique_ptr<act::gps::activity> _smoothed_data;
}

- (IBAction)controlAction:(id)sender;

@end
