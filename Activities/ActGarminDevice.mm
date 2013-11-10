/* -*- c-style: gnu -*-

   Copyright (c) 2013 John Harper <jsh@unfactored.org>

   Permission is hereby granted, free of charge, to any person
   obtaining a copy of this software and associated documentation files
   (the "Software"), to deal in the Software without restriction,
   including without limitation the rights to use, copy, modify, merge,
   publish, distribute, sublicense, and/or sell copies of the Software,
   and to permit persons to whom the Software is furnished to do so,
   subject to the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE. */

#import "ActGarminDevice.h"

// FIXME: really we should look for and parse the GarminDevice.xml file
// in the root of the device's filesystem. But that's a lot of work
// that's not really needed right now.

#define ACTIVITTY_PATH "Activities"

@implementation ActGarminDevice

@synthesize path = _path;

- (id)initWithPath:(NSString *)path
{
  self = [super init];
  if (self == nil)
    return nil;

  _path = [path copy];

  return self;
}

- (void)dealloc
{
  [_path release];

  [super dealloc];
}

- (NSString *)name
{
  return [_path lastPathComponent];
}

- (NSArray *)activityURLs
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *path = [_path stringByAppendingPathComponent:@ACTIVITTY_PATH];

  if (![fm fileExistsAtPath:path])
    return [NSArray array];

  NSMutableArray *array = [NSMutableArray array];

  for (NSString *file in [fm contentsOfDirectoryAtPath:path error:nullptr])
    {
      if ([[file pathExtension] isEqualToString:@"fit"])
	[array addObject:[NSURL fileURLWithPath:[path stringByAppendingPathComponent:file]]];
    }

  return array;
}

@end
