
#import "LWHTTPConnection.h"
#import "HTTPMessage.h"
#import "HTTPDataResponse.h"
#import "DDNumber.h"
#import "HTTPLogging.h"

#import "MultipartFormDataParser.h"
#import "MultipartMessageHeaderField.h"
#import "HTTPDynamicFileResponse.h"
#import "HTTPFileResponse.h"

// Log levels : off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_VERBOSE; // | HTTP_LOG_FLAG_TRACE;

//{wenjunlin
static __weak id g_target = nil;
static SEL g_action = nil;
//wenjunlin}


/**
 * All we have to do is override appropriate methods in HTTPConnection.
 **/

@implementation LWHTTPConnection

//{wenjunlin
+ (void)setTarget:(id)target action:(SEL)action
{
    g_target = target;
    g_action = action;
}
//wenjunlin}

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
	HTTPLogTrace();
	
	// Add support for POST
	
	if ([method isEqualToString:@"POST"])
	{
		if ([path isEqualToString:@"/upload.html"])
		{
			return YES;
		}
	}
	
	return [super supportsMethod:method atPath:path];
}

- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path
{
	HTTPLogTrace();
	
	// Inform HTTP server that we expect a body to accompany a POST request
	
	if([method isEqualToString:@"POST"] && [path isEqualToString:@"/upload.html"]) {
        // here we need to make sure, boundary is set in header
        NSString* contentType = [request headerField:@"Content-Type"];
        int paramsSeparator = [contentType rangeOfString:@";"].location;
        if( NSNotFound == paramsSeparator ) {
            return NO;
        }
        if( paramsSeparator >= contentType.length - 1 ) {
            return NO;
        }
        NSString* type = [contentType substringToIndex:paramsSeparator];
        if( ![type isEqualToString:@"multipart/form-data"] ) {
            // we expect multipart/form-data content type
            return NO;
        }

		// enumerate all params in content-type, and find boundary there
        NSArray* params = [[contentType substringFromIndex:paramsSeparator + 1] componentsSeparatedByString:@";"];
        for( NSString* param in params ) {
            paramsSeparator = [param rangeOfString:@"="].location;
            if( (NSNotFound == paramsSeparator) || paramsSeparator >= param.length - 1 ) {
                continue;
            }
            NSString* paramName = [param substringWithRange:NSMakeRange(1, paramsSeparator-1)];
            NSString* paramValue = [param substringFromIndex:paramsSeparator+1];
            
            if( [paramName isEqualToString: @"boundary"] ) {
                // let's separate the boundary from content-type, to make it more handy to handle
                [request setHeaderField:@"boundary" value:paramValue];
            }
        }
        // check if boundary specified
        if( nil == [request headerField:@"boundary"] )  {
            return NO;
        }
        return YES;
    }
	return [super expectsRequestBodyFromMethod:method atPath:path];
}

//{wenjunlin
//打印文件上传结果到响应体中
- (NSString *)printUploadResultForFile:(NSString *)fileName success:(BOOL)success
{
    if (success) {
        return [NSString stringWithFormat:@"<a href=\"/upload/%@\"> %@ </a><br/>", fileName, fileName];
    }
    return [NSString stringWithFormat:@"%@ already exists<br/>", fileName];
}
//wenjunlin}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
	HTTPLogTrace();
	
    //wenjunlin 处理上传的响应
	if ([method isEqualToString:@"POST"] && [path isEqualToString:@"/upload.html"])
	{
		// this method will generate response with links to uploaded file
		NSMutableString* filesStr = [[NSMutableString alloc] init];

        //生成文件上传结果的响应
		for( NSDictionary* file in uploadedFiles ) {
            NSString *fileName = [file allKeys][0];//文件名
            NSNumber *success = [file allValues][0];//上传是否成功
            
            NSString *result = nil;
            
            if ([g_target respondsToSelector: g_action]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                result = [g_target performSelector:g_action withObject:fileName withObject:success];
#pragma clang diagnostic pop
            } else {
                result = [self printUploadResultForFile:fileName success:success];
            }
            [filesStr appendString:result];
		}
        //wenjunlin 替换上传文件的结果
		NSString* templatePath = [[config documentRoot] stringByAppendingPathComponent:@"upload.html"];
		NSDictionary* replacementDict = [NSDictionary dictionaryWithObject:filesStr forKey:@"MyFiles"];
		// use dynamic file response to apply our links to response template
		return [[HTTPDynamicFileResponse alloc] initWithFilePath:templatePath forConnection:self separator:@"%" replacementDictionary:replacementDict];
	}
	if( [method isEqualToString:@"GET"] && [path hasPrefix:@"/upload/"] ) {
		// let download the uploaded files
		return [[HTTPFileResponse alloc] initWithFilePath: [[config documentRoot] stringByAppendingString:path] forConnection:self];
	}
	
	return [super httpResponseForMethod:method URI:path];
}

- (void)prepareForBodyWithSize:(UInt64)contentLength
{
	HTTPLogTrace();
	
	// set up mime parser
    NSString* boundary = [request headerField:@"boundary"];
    parser = [[MultipartFormDataParser alloc] initWithBoundary:boundary formEncoding:NSUTF8StringEncoding];
    parser.delegate = self;

	uploadedFiles = [[NSMutableArray alloc] init];
}

- (void)processBodyData:(NSData *)postDataChunk
{
	HTTPLogTrace();
    // append data to the parser. It will invoke callbacks to let us handle
    // parsed data.
    [parser appendData:postDataChunk];
}


//-----------------------------------------------------------------
#pragma mark multipart form data parser delegate

//处理上传的文件
- (void) processStartOfPartWithHeader:(MultipartMessageHeader*) header {
	// in this sample, we are not interested in parts, other then file parts.
	// check content disposition to find out filename

    MultipartMessageHeaderField* disposition = [header.fields objectForKey:@"Content-Disposition"];
	NSString* filename = [[disposition.params objectForKey:@"filename"] lastPathComponent];

    if ( (nil == filename) || [filename isEqualToString: @""] ) {
        // it's either not a file part, or
		// an empty form sent. we won't handle it.
		return;
	}    
	NSString* uploadDirPath = [[config documentRoot] stringByAppendingPathComponent:@"upload"];

    NSString* filePath = [uploadDirPath stringByAppendingPathComponent: filename];
    //wenjunlin 要上传的文件和已经存在的文件同名，放弃
    if( [[NSFileManager defaultManager] fileExistsAtPath:filePath] ) {
        storeFile = nil;
        //wjl
        [uploadedFiles addObject:@{filename: @NO}];
    }
    else {//wenjunlin 准备接收要上传的文件
		HTTPLogVerbose(@"Saving file to %@", filePath);
		[[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];	
		storeFile = [NSFileHandle fileHandleForWritingAtPath:filePath];
		//[uploadedFiles addObject: [NSString stringWithFormat:@"/upload/%@", filename]];
        //wjl
        [uploadedFiles addObject:@{filename: @YES}];
    }
}


- (void) processContent:(NSData*) data WithHeader:(MultipartMessageHeader*) header 
{
	// here we just write the output from parser to the file.
	if( storeFile ) {
		[storeFile writeData:data];
	}
}

- (void) processEndOfPartWithHeader:(MultipartMessageHeader*) header
{
	// as the file part is over, we close the file.
	[storeFile closeFile];
	storeFile = nil;
}

- (void) processPreambleData:(NSData*) data 
{
    // if we are interested in preamble data, we could process it here.

}

- (void) processEpilogueData:(NSData*) data 
{
    // if we are interested in epilogue data, we could process it here.

}

@end
