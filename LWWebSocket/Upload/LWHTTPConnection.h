
#import "HTTPConnection.h"

@class MultipartFormDataParser;

@interface LWHTTPConnection : HTTPConnection  {
    MultipartFormDataParser*        parser;
	NSFileHandle*					storeFile;
	
	NSMutableArray*					uploadedFiles;
}

//{wenjunlin
+ (void)setTarget:(id)target action:(SEL)action;
//wenjunlin}

@end
