// -*- c-style: gnu -*-

#import <Foundation/Foundation.h>

struct ActMapTileIndex
{
  int x;
  int y;
  int z;

  ActMapTileIndex(int x, int y, int z);
};

// Abstract map-source class

@interface ActMapSource : NSObject

@property(nonatomic, readonly, getter=isLoading) BOOL loading;

@property(nonatomic, readonly) NSString *name;
@property(nonatomic, readonly) NSString *scheme;
@property(nonatomic, readonly) int minZoom;
@property(nonatomic, readonly) int maxZoom;
@property(nonatomic, readonly) int tileWidth;
@property(nonatomic, readonly) int tileHeight;

- (NSURL *)URLForTileIndex:(const ActMapTileIndex &)tile;

@end

// ActMapSource notifications

extern NSString *const ActMapSourceDidFinishLoading;

// implementation details

inline
ActMapTileIndex::ActMapTileIndex(int a, int b, int c)
: x(a), y(b), z(c)
{
}
