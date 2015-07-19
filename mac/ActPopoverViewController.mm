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
{
  CGFloat _baseHeight;

  NSTextView *_bodyTextView;
  NSLayoutManager *_bodyLayoutManager;
  NSTextContainer *_bodyLayoutContainer;

  act::activity_storage_ref _activityStorage;
  std::unique_ptr<act::activity> _activity;
}

@synthesize typeField = _typeField;
@synthesize dateField = _dateField;
@synthesize courseField = _courseField;
@synthesize distanceLabel = _distanceLabel;
@synthesize distanceField = _distanceField;
@synthesize durationLabel = _durationLabel;
@synthesize durationField = _durationField;
@synthesize paceLabel = _paceLabel;
@synthesize paceField = _paceField;
@synthesize pointsLabel = _pointsLabel;
@synthesize pointsField = _pointsField;

+ (NSString *)viewNibName
{
  return @"ActPopoverView";
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  _baseHeight = self.view.frame.size.height;

  _bodyTextView = [[NSTextView alloc] initWithFrame:NSZeroRect];
  _bodyTextView.editable = NO;
  _bodyTextView.richText = NO;
  _bodyTextView.usesFontPanel = NO;
  _bodyTextView.importsGraphics = NO;
  _bodyTextView.drawsBackground = NO;
  _bodyTextView.font = [ActFont bodyFontOfSize:11];
  _bodyTextView.textColor = [ActColor controlTextColor];
  [self.view addSubview:_bodyTextView];

  _bodyLayoutContainer = [[NSTextContainer alloc]
			  initWithContainerSize:NSZeroSize];
  _bodyLayoutContainer.lineFragmentPadding = 0;
  _bodyLayoutManager = [[NSLayoutManager alloc] init];
  [_bodyLayoutManager addTextContainer:_bodyLayoutContainer];
  [_bodyTextView.textStorage addLayoutManager:_bodyLayoutManager];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeField:)
   name:ActActivityDidChangeField object:self.controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeBody:)
   name:ActActivityDidChangeBody object:self.controller];

  NSColor *greyColor = [ActColor controlTextColor];
  NSColor *redColor = [ActColor controlDetailTextColor];

  _typeField.textColor = greyColor;
  _dateField.textColor = greyColor;
  _courseField.textColor = greyColor;
  _distanceLabel.textColor = greyColor;
  _distanceField.textColor = redColor;
  _durationLabel.textColor = greyColor;
  _durationField.textColor = redColor;
  _paceLabel.textColor = greyColor;
  _paceField.textColor = redColor;
  _pointsLabel.textColor = greyColor;
  _pointsField.textColor = redColor;

  [self reloadFields];
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
  void *ptr = [note.userInfo[@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);

  if (a == _activityStorage)
    [self reloadFields];
}

- (void)activityDidChangeBody:(NSNotification *)note
{
  void *ptr = [note.userInfo[@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);

  if (a == _activityStorage)
    _bodyTextView.string = self.controller.bodyString;
}

- (void)reloadFields
{
  static NSDateFormatter *date_formatter;
  static dispatch_once_t once;

  dispatch_once(&once, ^
    {
      date_formatter = [[NSDateFormatter alloc] init];
      NSLocale *locale = ((ActAppDelegate *)[NSApp delegate]).currentLocale;
      date_formatter.locale = locale;
      date_formatter.dateFormat =
       [NSDateFormatter dateFormatFromTemplate:
	@"E dd MMM yyyy ha" options:0 locale:locale];
    });

  ActWindowController *controller = self.controller;

  if (_activity)
    {
      _typeField.objectValue =
       [NSString stringWithFormat:@"%@ / %@",
	[controller stringForField:@"activity" ofActivity:*_activity],
	[controller stringForField:@"type" ofActivity:*_activity]];
      _dateField.objectValue =
       [NSDate dateWithTimeIntervalSince1970:_activity->date()];
      _courseField.objectValue =
       [controller stringForField:@"course" ofActivity:*_activity];
      _distanceField.objectValue =
       [controller stringForField:@"distance" ofActivity:*_activity];
      _durationField.objectValue =
       [controller stringForField:@"duration" ofActivity:*_activity];
      _paceField.objectValue =
       [controller stringForField:@"pace" ofActivity:*_activity];
      _pointsField.objectValue =
       [controller stringForField:@"points" ofActivity:*_activity];
      _bodyTextView.string = [controller bodyStringOfActivity:*_activity];
    }
  else
    {
      _typeField.objectValue = nil;
      _dateField.objectValue = nil;
      _distanceField.objectValue = nil;
      _durationField.objectValue = nil;
      _paceField.objectValue = nil;
      _pointsField.objectValue = nil;
      _bodyTextView.string = @"";
    }
}

- (void)sizeToFit
{
  NSView *view = self.view;
  NSRect old_frame = view.frame;

  // See https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html
 
  _bodyLayoutContainer.containerSize =
   NSMakeSize(old_frame.size.width - BODY_X_INSET*2, CGFLOAT_MAX);
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
  _bodyTextView.frame = view_frame;
}

@end
