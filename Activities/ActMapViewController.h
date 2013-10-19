// -*- c-style: gnu -*-

#import "ActViewController.h"

@class ActMapView;

@interface ActMapViewController : ActViewController
{
  IBOutlet ActMapView *_mapView;
  IBOutlet NSPopUpButton *_mapSrcButton;
  IBOutlet NSSlider *_zoomSlider;
  IBOutlet NSButton *_zoomInButton;
  IBOutlet NSButton *_zoomOutButton;
  IBOutlet NSButton *_centerButton;

  int _pendingSources;
  NSString *_defaultSourceName;
}

- (IBAction)controlAction:(id)sender;

@end
