//
//  LWWebSocket.m
//  LWHttpServerDemo
//
//  Created by LaoWen on 16/5/5.
//  Copyright © 2016年 LaoWen. All rights reserved.
//
#import "HTTPServer.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "LWHTTPConnection.h"

#import "LWWebSocket.h"

@implementation LWWebSocket
{
    HTTPServer *httpServer;
    int ddLogLevel;
}

- (void)setDelegate:(id<LWWebSocketDelegate>)delegate
{
    [LWHTTPConnection setTarget:delegate action:@selector(lwwebSocketPrintUploadResultForFile:success:)];
}

- (id)initWithRootDir:(NSString *)rootDir andPort:(int)port
{
    if (self = [super init]) {
        // Log levels: off, error, warn, info, verbose
        ddLogLevel = LOG_LEVEL_VERBOSE;
        [DDLog addLogger:[DDTTYLogger sharedInstance]];
        
        // Initalize our http server
        httpServer = [[HTTPServer alloc] init];
        
        // Tell the server to broadcast its presence via Bonjour.
        // This allows browsers such as Safari to automatically discover our service.
        [httpServer setType:@"_http._tcp."];
        
        // Normally there's no need to run our server on any specific port.
        // Technologies like Bonjour allow clients to dynamically discover the server's port at runtime.
        // However, for easy testing you may want force a certain port so you can just hit the refresh button.
        //	[httpServer setPort:12345];

        DDLogInfo(@"Setting document root: %@", rootDir);
        [httpServer setDocumentRoot:rootDir];//设置根目录
        
        NSFileManager *fm = [NSFileManager defaultManager];
        
        //创建upload目录
        NSString *uploadDir = [rootDir stringByAppendingPathComponent: @"upload"];
        if (![fm fileExistsAtPath:uploadDir]) {
            [fm createDirectoryAtPath:uploadDir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        //copy两个默认网页
        for (NSString *fileName in @[@"index.html", @"upload.html"]) {
            //index.html和upload.html是用户定制的首页和首页的响应页面，优先考虑
            NSString *srcPath = [[NSBundle mainBundle]pathForResource:fileName ofType:nil];
            if (!srcPath) {
                //如果用户没有定制这两个页面，则使用Templateindex.html和Templateupload.html这两个默认的页面
                NSString *srcFileName = [NSString stringWithFormat:@"Template%@", fileName];
                srcPath = [[NSBundle mainBundle]pathForResource:srcFileName ofType:nil];
            }

            NSString *destPath = [rootDir stringByAppendingPathComponent:fileName];
            
            //沙盒里不存在这个文件，直接拷贝
            if (![fm fileExistsAtPath:destPath]) {
                [fm copyItemAtPath:srcPath toPath:destPath error:nil];
            } else {
                //检查沙盒里的文件和修改时间
                
                NSDictionary *srcAttribute = [fm attributesOfItemAtPath:srcPath error:nil];
                NSDictionary *destAttribute = [fm attributesOfItemAtPath:destPath error:nil];
                //模版文件比沙盒里的新，先删掉沙盒里的文件再copy
                if ([srcAttribute.fileModificationDate compare:destAttribute.fileModificationDate] == NSOrderedDescending) {
                    [fm removeItemAtPath:destPath error:nil];
                    [fm copyItemAtPath:srcPath toPath:destPath error:nil];
                }
            }
        }
        
        httpServer.port = port;//设置端口号
        
        [httpServer setConnectionClass:[LWHTTPConnection class]];//用LWHttpConnection替换默认的以支持upload
    }
    return self;
}

- (void)start
{
    NSError *error = nil;
    if(![httpServer start:&error])
    {
        DDLogError(@"Error starting HTTP Server: %@", error);
    }
}

- (void)stop
{
    [httpServer stop];
}

- (NSString *)uploadPath
{
    NSString *uploadDir = [[httpServer documentRoot]stringByAppendingPathComponent:@"upload"];
    return uploadDir;
}

- (NSArray *)allUploadedFiles
{
    NSString *uploadDir = [self uploadPath];
    NSArray *files = [[NSFileManager defaultManager]contentsOfDirectoryAtPath:uploadDir error:nil];
    return files;
}

//删除所有已上传的文件
- (void)clean
{
    NSString *dir = [self uploadPath];
    NSArray *files = [self allUploadedFiles];
    for (NSString *file in files) {
        NSString *path = [dir stringByAppendingPathComponent:file];
        [[NSFileManager defaultManager]removeItemAtPath:path error:nil];
    }
}

@end
