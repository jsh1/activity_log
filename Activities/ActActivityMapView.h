// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

@class ActMapView;

@interface ActActivityMapView : ActActivitySubview
{
  IBOutlet ActMapView *_mapView;
  IBOutlet NSPopUpButton *_mapSrcButton;
  IBOutlet NSSlider *_zoomSlider;
  IBOutlet NSButton *_zoomInButton;
  IBOutlet NSButton *_zoomOutButton;
  IBOutlet NSButton *_centerButton;

  int _pendingSources;
}

- (IBAction)controlAction:(id)sender;

@end
