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

#import "ActPopoverViewController.h"

#import "ActAppDelegate.h"
#import "ActColor.h"
#import "ActFont.h"
#import "ActWindowController.h"

#define BODY_X_INSET 6
#define MIN_BODY_HEIGHT 60
#define MAX_BODY_HEIGHT 400

@interface ActPopoverViewController ()
- (void)reloadFields;
- (void)sizeToFit;
@end

@implementation ActPopoverViewController

+ (NSString *)viewNibName
{
  return @"ActPopoverView";
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  _baseHeight = [[self view] frame].size.height;

  _bodyTextView = [[NSTextView alloc] initWithFrame:NSZeroRect];
  [_bodyTextView setEditable:NO];
  [_bodyTextView setRichText:NO];
  [_bodyTextView setUsesFontPanel:NO];
  [_bodyTextView setImportsGraphics:NO];
  [_bodyTextView setDrawsBackground:NO];
  [_bodyTextView setFont:[ActFont bodyFontOfSize:11]];
  [_bodyTextView setTextColor:[ActColor controlTextColor]];
  [[self view] addSubview:_bodyTextView];
  [_bodyTextView release];

  _bodyLayoutContainer = [[NSTextContainer alloc]
			  initWithContainerSize:NSZeroSize];
  [_bodyLayoutContainer setLineFragmentPadding:0];
  _bodyLayoutManager = [[NSLayoutManager alloc] init];
  [_bodyLayoutManager addTextContainer:_bodyLayoutContainer];
  [[_bodyTextView textStorage] addLayoutManager:_bodyLayoutManager];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeField:)
   name:ActActivityDidChangeField object:_controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeBody:)
   name:ActActivityDidChangeBody object:_controller];

  NSColor *greyColor = [ActColor controlTextColor];
  NSColor *redColor = [ActColor controlDetailTextColor];

  [_typeField setTextColor:greyColor];
  [_dateField setTextColor:greyColor];
  [_courseField setTextColor:greyColor];
  [_distanceLabel setTextColor:greyColor];
  [_distanceField setTextColor:redColor];
  [_durationLabel setTextColor:greyColor];
  [_durationField setTextColor:redColor];
  [_paceLabel setTextColor:greyColor];
  [_paceField setTextColor:redColor];
  [_pointsLabel setTextColor:greyColor];
  [_pointsField setTextColor:redColor];

  [self reloadFields];
}

- (void)dealloc
{
  [_bodyLayoutManager release];
  [_bodyLayoutContainer release];
  [super dealloc];
}

- (void)setActivityStorage:(act::activity_storage_ref)storage
{
  if (_activityStorage != storage)
    {
      _activityStorage = storage;
      _activity.reset(new act::activity(_activityStorage));

      [self reloadFields];
    }
}

- (act::activity_storage_ref)activityStorage
{
  return _activityStorage;
}

- (void)activityDidChangeField:(NSNotification *)note
{
  void *ptr = [[[note userInfo] objectForKey:@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);

  if (a == _activityStorage)
    [self reloadFields];
}

- (void)activityDidChangeBody:(NSNotification *)note
{
  void *ptr = [[[note userInfo] objectForKey:@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);

  if (a == _activityStorage)
    [_bodyTextView setString:[_controller bodyString]];
}

- (void)reloadFields
{
  static NSDateFormatter *date_formatter;
  static dispatch_once_t once;

  dispatch_once(&once, ^
    {
      date_formatter = [[NSDateFormatter alloc] init];
      NSLocale *locale = [(ActAppDelegate *)[NSApp delegate] currentLocale];
      [date_formatter setLocale:locale];
      [date_formatter setDateFormat:
       [NSDateFormatter dateFormatFromTemplate:
	@"E dd MMM yyyy ha" options:0 locale:locale]];
    });

  if (_activity)
    {
      [_typeField setObjectValue:
       [NSString stringWithFormat:@"%@ / %@",
	[_controller stringForField:@"activity" ofActivity:*_activity],
	[_controller stringForField:@"type" ofActivity:*_activity]]];
      [_dateField setObjectValue:[date_formatter stringFromDate:
       [NSDate dateWithTimeIntervalSince1970:_activity->date()]]];
      [_courseField setObjectValue:
       [_controller stringForField:@"course" ofActivity:*_activity]];
      [_distanceField setObjectValue:
       [_controller stringForField:@"distance" ofActivity:*_activity]];
      [_durationField setObjectValue:
       [_controller stringForField:@"duration" ofActivity:*_activity]];
      [_paceField setObjectValue:
       [_controller stringForField:@"pace" ofActivity:*_activity]];
      [_pointsField setObjectValue:
       [_controller stringForField:@"points" ofActivity:*_activity]];
      [_bodyTextView setString:[_controller bodyStringOfActivity:*_activity]];
    }
  else
    {
      [_typeField setObjectValue:nil];
      [_dateField setObjectValue:nil];
      [_distanceField setObjectValue:nil];
      [_durationField setObjectValue:nil];
      [_paceField setObjectValue:nil];
      [_pointsField setObjectValue:nil];
      [_bodyTextView setString:@""];
    }
}

- (void)sizeToFit
{
  NSView *view = [self view];
  NSRect old_frame = [view frame];

  // See https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html
 
  [_bodyLayoutContainer setContainerSize:
   NSMakeSize(old_frame.size.width - BODY_X_INSET*2, CGFLOAT_MAX)];
  [_bodyLayoutManager glyphRangeForTextContainer:_bodyLayoutContainer];
 
  CGFloat new_height = ([_bodyLayoutManager usedRectForTextContainer:
			 _bodyLayoutContainer].size.height);
  new_height = ceil(new_height);
  new_height = std::max(new_height, (CGFloat)MIN_BODY_HEIGHT);
  new_height = std::min(new_height, (CGFloat)MAX_BODY_HEIGHT);

  NSRect new_frame = old_frame;
  new_frame.size.height = _baseHeight + new_height + 10;
  [view setFrameSize:new_frame.size];

  NSRect view_frame;
  view_frame.origin.x = BODY_X_INSET;
  view_frame.size.width = new_frame.size.width - BODY_X_INSET*2;
  view_frame.origin.y = 10;
  view_frame.size.height = new_height;
  [_bodyTextView setFrame:view_frame];
}

@end
