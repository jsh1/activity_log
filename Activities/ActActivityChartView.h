// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

#import "act-gps-chart.h"

#import <memory>

enum ActActivityChartType
{
  CHART_NONE,
  CHART_PACE,
  CHART_HEART_RATE,
  CHART_ALTITUDE,
};

@interface ActActivityChartView : ActActivitySubview
{
  ActActivityChartType _chartType;
  std::unique_ptr<act::gps::chart> _chart;
}

@property ActActivityChartType chartType;

@end

@interface ActActivityPaceChartView : ActActivityChartView
@end

@interface ActActivityHeartRateChartView : ActActivityChartView
@end

@interface ActActivityAltitudeChartView : ActActivityChartView
@end
