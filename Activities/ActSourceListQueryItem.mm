// -*- c-style: gnu -*-

#import "ActSourceListQueryItem.h"

#import "ActWindowController.h"

@implementation ActSourceListQueryItem

@synthesize query = _query;

- (BOOL)hasBadge
{
  return YES;
}

- (NSInteger)badgeValue
{
  std::vector<act::database::item *> items;
  [_controller database]->execute_query(_query, items);

  return (NSInteger)items.size();
}

- (void)select
{
  [_controller showQueryResults:_query];
  [_controller setWindowMode:ActWindowMode_Viewer];
}

@end
