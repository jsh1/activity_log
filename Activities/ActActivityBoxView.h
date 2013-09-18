// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

@interface ActActivityBoxView : ActActivitySubview
{
  BOOL _vertical;
}

@property(nonatomic, getter=isVertical) BOOL vertical;

@end
