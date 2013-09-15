// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

#import "act-gps-chart.h"

#import <memory>

@interface ActActivityChartView : ActActivitySubview
{
  IBOutlet NSSegmentedControl *_segmentedControl;

  std::unique_ptr<act::gps::chart> _chart;
}

- (IBAction)controlAction:(id)sender;

@end
