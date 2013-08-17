// -*- c-style: gnu -*-

#import "ActActivityView.h"

@implementation ActActivityView

- (act::activity_storage_ref)activityStorage
{
  return _activity_storage;
}

- (void)setActivityStorage:(act::activity_storage_ref)storage
{
  if (_activity_storage != storage)
    {
      _activity_storage = storage;

      // FIXME: update view
    }
}

@end
