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

#import "ActSummaryViewController.h"

#import "ActAppDelegate.h"
#import "ActCollapsibleView.h"
#import "ActColor.h"
#import "ActFont.h"
#import "ActHorizontalBoxView.h"
#import "ActViewLayout.h"
#import "ActWindowController.h"

#import "act-database.h"

#import "FoundationExtensions.h"

#define BODY_X_INSET 6
#define BODY_Y_INSET 10
#define BODY_SPACING 8
#define BODY_BOTTOM_BORDER 14
#define MAX_BODY_WIDTH 560
#define MIN_BODY_HEIGHT 42

@implementation ActSummaryViewController
{
  NSTextView *_bodyTextView;
  NSLayoutManager *_bodyLayoutManager;
  NSTextContainer *_bodyLayoutContainer;

  NSDictionary *_fieldControls;		// FIELD-NAME -> CONTROL

  int _ignoreChanges;
}

@synthesize summaryView = _summaryView;
@synthesize dateBox = _dateBox;
@synthesize dateTimeField = _dateTimeField;
@synthesize dateDayField = _dateDayField;
@synthesize dateDateField = _dateDateField;
@synthesize typeBox = _typeBox;
@synthesize typeActivityField = _typeActivityField;
@synthesize typeTypeField = _typeTypeField;
@synthesize statsBox = _statsBox;
@synthesize statsDistanceField = _statsDistanceField;
@synthesize statsDurationField = _statsDurationField;
@synthesize statsPaceField = _statsPaceField;
@synthesize courseField = _courseField;

+ (NSString *)viewNibName
{
  return @"ActSummaryView";
}

- (id)initWithController:(ActWindowController *)controller
    options:(NSDictionary *)opts
{
  self = [super initWithController:controller options:opts];
  if (self == nil)
    return nil;

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(selectedActivityDidChange:)
   name:ActSelectedActivityDidChange object:self.controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeField:)
   name:ActActivityDidChangeField object:self.controller];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(activityDidChangeBody:)
   name:ActActivityDidChangeBody object:self.controller];

  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  ((ActCollapsibleView *)self.view).title = @"Summary & Notes";
  ((ActCollapsibleView *)self.view).headerInset = 10;

  /* creating layers for each subview is not gaining us anything

     FIXME: broken from 10.10 onwards, text fields don't update after
     creating view. */

#if 0
  self.view.canDrawSubviewsIntoLayer = YES;
#endif

  _dateBox.rightToLeft = YES;
  _dateBox.spacing = 1;
  _typeBox.spacing = 3;
  _typeBox.rightToLeft = YES;
  _statsBox.spacing = 8;

  _bodyTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 500, 32)];
  _bodyTextView.allowsUndo = YES;
  _bodyTextView.richText = NO;
  _bodyTextView.usesFontPanel = NO;
  _bodyTextView.importsGraphics = NO;
  _bodyTextView.drawsBackground = NO;
  _bodyTextView.font = [ActFont bodyFontOfSize:12];
  _bodyTextView.textColor = [ActColor controlTextColor];
  _bodyTextView.delegate = self;
  [_summaryView addSubview:_bodyTextView];

  _bodyLayoutContainer = [[NSTextContainer alloc]
			  initWithContainerSize:NSZeroSize];
  _bodyLayoutContainer.lineFragmentPadding = 0;
  _bodyLayoutManager = [[NSLayoutManager alloc] init];
  [_bodyLayoutManager addTextContainer:_bodyLayoutContainer];
  [_bodyTextView.textStorage addLayoutManager:_bodyLayoutManager];

  _courseField.completesEverything = YES;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [_bodyTextView setDelegate:nil];


}

- (NSView *)initialFirstResponder
{
  return _courseField;
}

- (NSDictionary *)fieldControls
{
  if (_fieldControls == nil)
    {
      _fieldControls = @{
	@"activity": _typeActivityField,
	@"type": _typeTypeField,
	@"distance":_statsDistanceField,
	@"duration": _statsDurationField,
	@"pace": _statsPaceField,
	@"course": _courseField,
      };
    }

  return _fieldControls;
}

- (CGFloat)heightOfView:(NSView *)view forWidth:(CGFloat)width
{
  if (view == _summaryView)
    {
      // See https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html

      CGFloat body_width = std::min(width - BODY_X_INSET*2,
				    (CGFloat)MAX_BODY_WIDTH);

      _bodyLayoutContainer.containerSize = NSMakeSize(body_width, CGFLOAT_MAX);
      [_bodyLayoutManager glyphRangeForTextContainer:_bodyLayoutContainer];
 
      CGFloat body_height = ([_bodyLayoutManager usedRectForTextContainer:
			      _bodyLayoutContainer].size.height
			     + BODY_BOTTOM_BORDER);
      body_height = std::max(ceil(body_height), (CGFloat)MIN_BODY_HEIGHT);

      NSRect r = NSUnionRect(_statsBox.frame, _courseField.frame);
      r.size.height += BODY_SPACING + body_height;

      return r.size.height;
    }
  else
    return [view heightForWidth:width];
}

- (void)layoutSubviewsOfView:(NSView *)view
{
  if (view == _summaryView)
    {
      [_dateBox layoutSubviews];
      [_typeBox layoutSubviews];
      [_statsBox layoutSubviews];

      NSRect bounds = view.bounds;
      NSRect top = NSUnionRect(_statsBox.frame, _courseField.frame);

      CGFloat body_width = std::min(bounds.size.width - BODY_X_INSET*2,
				    (CGFloat)MAX_BODY_WIDTH);

      NSRect frame;
      frame.origin.x = bounds.origin.x + BODY_X_INSET;
      frame.origin.y = bounds.origin.y + BODY_Y_INSET;
      frame.size.width = body_width;
      frame.size.height = (top.origin.y - BODY_SPACING) - frame.origin.y;
      _bodyTextView.frame = frame;
    }
}

- (void)_reloadFields
{
  ActWindowController *controller = self.controller;

  if (controller.selectedActivity != nullptr)
    {
      NSDate *date = controller.dateField;
      NSDateFormatter *formatter = [[NSDateFormatter alloc] init];

      formatter.locale = ((ActAppDelegate *)NSApp.delegate).currentLocale;
      formatter.dateStyle = NSDateFormatterShortStyle;
      formatter.timeStyle = NSDateFormatterNoStyle;
      _dateDateField.stringValue = [formatter stringFromDate:date];

      NSInteger day = [[NSCalendar currentCalendar] components:
			NSCalendarUnitWeekday fromDate:date].weekday;
      _dateDayField.stringValue =
       [NSString stringWithFormat:@"on %@", formatter.weekdaySymbols[day - 1]];

      formatter.dateStyle = NSDateFormatterNoStyle;
      formatter.timeStyle = NSDateFormatterShortStyle;
      _dateTimeField.stringValue = [formatter stringFromDate:date];


      NSDictionary *dict = self.fieldControls;
      for (NSString *field in dict)
	{
	  NSString *string = [controller stringForField:field];
	  NSTextField *control = dict[field];
	  control.stringValue = string;
	  BOOL readOnly = [controller isFieldReadOnly:field];
	  control.editable = !readOnly;
	  NSColor *color;
	  if (control.superview != _statsBox)
	    color = [ActColor controlTextColor:readOnly];
	  else
	    color = [ActColor controlDetailTextColor:readOnly];
	  control.textColor = color;
	}

      _bodyTextView.string = controller.bodyString;
    }
  else
    {
      _dateDateField.objectValue = nil;
      _dateDayField.objectValue = nil;
      _dateTimeField.objectValue = nil;

      NSDictionary *dict = self.fieldControls;
      NSColor *color = [ActColor disabledControlTextColor];

      for (NSString *field in dict)
	{
	  NSTextField *control = dict[field];

	  control.objectValue = nil;
	  control.editable = NO;
	  control.textColor = color;
	}

      _bodyTextView.string = @"";
    }

  [self layoutSubviewsOfView:_summaryView];
}

- (void)selectedActivityDidChange:(NSNotification *)note
{
  [self _reloadFields];
}

- (void)activityDidChangeField:(NSNotification *)note
{
  if (_ignoreChanges != 0)
    return;

  void *ptr = [note.userInfo[@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);

  if (a == self.controller.selectedActivityStorage)
    [self _reloadFields];
}

- (void)activityDidChangeBody:(NSNotification *)note
{
  if (_ignoreChanges != 0)
    return;

  void *ptr = [note.userInfo[@"activity"] pointerValue];
  const auto &a = *reinterpret_cast<const act::activity_storage_ref *> (ptr);

  if (a == self.controller.selectedActivityStorage)
    _bodyTextView.string = self.controller.bodyString;
}

- (IBAction)controlAction:(id)sender
{
  if (![sender isEditable])
    return;

  NSDictionary *dict = self.fieldControls;

  for (NSString *fieldName in dict)
    {
      if (dict[fieldName] == sender)
	{
	  [self.controller setString:[sender stringValue] forField:fieldName];
	  return;
	}
    }

  if (sender == _dateTimeField || sender == _dateDateField)
    {
      NSString *str = [NSString stringWithFormat:@"%@ %@",
		       _dateDateField.stringValue, _dateTimeField.stringValue];

      NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
      formatter.locale = ((ActAppDelegate *)NSApp.delegate).currentLocale;
      formatter.dateStyle = NSDateFormatterShortStyle;
      formatter.timeStyle = NSDateFormatterShortStyle;

      // FIXME: mark invalid dates somehow?

      if (NSDate *date = [formatter dateFromString:str])
	self.controller.dateField = date;

      return;
    }
}

// NSControlTextEditingDelegate methods

- (BOOL)control:(NSControl *)control
    textShouldEndEditing:(NSText *)fieldEditor
{
  [self controlAction:control];
  return YES;
}

- (NSArray *)control:(NSControl *)control textView:(NSTextView *)textView
    completions:(NSArray *)words forPartialWordRange:(NSRange)charRange
    indexOfSelectedItem:(NSInteger *)index
{
  const char *field_name = nullptr;

  if (control == _typeTypeField)
    field_name = "Type";
  else if (control == _typeActivityField)
    field_name = "Activity";
  else if (control == _courseField)
    field_name = "Course";

  if (field_name != nullptr)
    {
      NSString *str = [textView.string substringWithRange:charRange];

      act::database *db = self.controller.database;

      std::vector<std::string> completions;
      db->complete_field_value(field_name, str.UTF8String, completions);

      NSMutableArray *array = [NSMutableArray array];
      for (const auto &it : completions)
	[array addObject:@(it.c_str())];

      return array;
    }

  return nil;
}

// NSTextViewDelegate methods

- (void)textDidChange:(NSNotification *)note
{
  if (note.object == _bodyTextView)
    {
      // FIXME: this might be too slow?
 
      NSRect bounds = _summaryView.bounds;
      if ([self heightOfView:_summaryView
	   forWidth:bounds.size.width] != bounds.size.height)
	[_summaryView.superview subviewNeedsLayout:_summaryView];

      _ignoreChanges++;
      self.controller.bodyString = _bodyTextView.string;
      _ignoreChanges--;
    }
}

- (void)textDidEndEditing:(NSNotification *)note
{
  if (note.object == _bodyTextView)
    {
      self.controller.bodyString = _bodyTextView.string;
    }
}

@end

@implementation ActSummaryView

@synthesize controller = _controller;

- (void)drawRect:(NSRect)r
{
  [[ActColor controlBackgroundColor] setFill];
  [NSBezierPath fillRect:r];
}

- (BOOL)isOpaque
{
  return YES;
}

@end
