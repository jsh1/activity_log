// -*- c-style: gnu -*-

#import "ActViewController.h"

@interface ActCollapsibleView : NSView
{
  IBOutlet NSView *_headerView;
  IBOutlet NSView *_contentView;

  IBOutlet id _delegate;

  NSButton *_disclosureButton;

  NSString *_title;
  NSSize _titleSize;

  CGFloat _headerInset;

  CGFloat _headerHeight;
  CGFloat _contentHeight;
}

@property(nonatomic, assign) id delegate;

@property(nonatomic, copy) NSString *title;
@property(nonatomic, getter=isCollapsed) BOOL collapsed;

@property(nonatomic, retain) NSView *headerView;
@property(nonatomic) CGFloat headerInset;

@property(nonatomic, retain) NSView *contentView;

@end

@interface NSObject (ActLayoutDelegate)

- (CGFloat)heightOfView:(NSView *)view forWidth:(CGFloat)width;

- (void)layoutSubviewsOfView:(NSView *)view;

@end
