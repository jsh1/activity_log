// -*- c-style: gnu -*-

#import "ActActivityBodyView.h"

#import "ActActivityView.h"

@implementation ActActivityBodyView

@synthesize activityView = _activityView;

- (NSString *)bodyString
{
  if (const act::activity *a = [_activityView activity])
    {
      const std::string &s = a->body();

      if (s.size() != 0)
	{
	  NSMutableString *str = [[NSMutableString alloc] init];

	  const char *ptr = s.c_str();

	  while (const char *eol = strchr(ptr, '\n'))
	    {
	      NSString *tem = [[NSString alloc] initWithBytes:ptr
			       length:eol-ptr encoding:NSUTF8StringEncoding];
	      [str appendString:tem];
	      [tem release];
	      ptr = eol + 1;
	      if (*ptr == '\n')
		[str appendString:@"\n\n"], ptr++;
	      else
		[str appendString:@" "];
	    }

	  if (*ptr != 0)
	    {
	      NSString *tem = [[NSString alloc] initWithUTF8String:ptr];
	      [str appendString:tem];
	      [tem release];
	    }

	  return str;
	}
    }

  return @"";
}

- (void)setBodyString:(NSString *)str
{
  // FIXME: implement this
}

- (void)activityDidChange
{
  [_textView setString:[self bodyString]];
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
  return 100; // FIXME:
}

- (void)layoutSubviews
{
  if (_textView == nil)
    {
      _textView = [[NSText alloc] initWithFrame:[self bounds]];
      [self addSubview:_textView];
      [_textView release];
    }

  [_textView setFrame:[self bounds]];
}

@end
