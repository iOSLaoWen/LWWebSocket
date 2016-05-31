//
//  LWWebSocket.h
//  LWHttpServerDemo
//
//  Created by LaoWen on 16/5/5.
//  Copyright © 2016年 LaoWen. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LWWebSocket;

@protocol LWWebSocketDelegate <NSObject>

- (NSString *)lwwebSocketPrintUploadResultForFile:(NSString *)fileName success:(NSNumber *)success;

@end

@interface LWWebSocket : NSObject

@property (nonatomic, weak)id<LWWebSocketDelegate>delegate;

//初始化
//参数1：http server的根目录
//参数2：http server的端口号
- (id)initWithRootDir:(NSString *)rootDir andPort:(int)port;

//启动http server
- (void)start;

//停止http server
- (void)stop;

//返回上传文件所在的绝对路径
- (NSString *)uploadPath;

//返回所有的上传的文件名，不带路径
- (NSArray *)allUploadedFiles;

//删除所有已上传的文件
- (void)clean;

@end
