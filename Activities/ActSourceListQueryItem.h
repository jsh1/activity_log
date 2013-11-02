// -*- c-style: gnu -*-

#import "ActSourceListItem.h"

#import "act-database.h"

@interface ActSourceListQueryItem : ActSourceListItem
{
  act::database::query _query;
}

@property(nonatomic, readonly) act::database::query &query;

@end
