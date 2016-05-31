//
//  ViewController.m
//  LWHttpServerDemo
//
//  Created by LaoWen on 16/5/4.
//  Copyright © 2016年 LaoWen. All rights reserved.
//

#import "ViewController.h"
#import "LWWebSocket.h"

@interface ViewController ()<LWWebSocketDelegate>

@end

@implementation ViewController
{
    LWWebSocket *_webSocket;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    /*
     LWWebSocket是在开源CocoaHttpServer的基础上经封装及整理形成的HttpServer库，支持文件的上传和下载，用法比较简单。
     最简单的用法是创建LWWebSocket的实例并用initWithRootDir:andPort初始化，两个参数分别是HttpServer的根目录（沙盒中的某个目录，写绝对路径）和端口号。然后调用start方法启动HttpServer。
     库中默认的主页可以用来上传文件并显示上传结果，您也可以自己定制这两个页面。只要您在工程中分别分别index.html和upload.html这两个文件即可。index.html为首页文件，upload.html为接收上传文件并显示上传结果的页面。唯一要注意的是index.html中form的action文件必须写成upload.html；upload.html中%MyFiles%部分会被替换为文件的上传结果。库的默认实现为上传成功的文件显示其超链接、失败的文件显示already exists。如果要定制文件的上传结果，可以设置代理并实现lwwebSocketPrintUploadResultForFile: success:方法。每一个上传的文件都会调用一次该方法。
        其它请参考LWWebSocket.h
     */
    
    NSString * docRoot = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    
    //创建Http Server并设置根目录和端口号
    _webSocket = [[LWWebSocket alloc]initWithRootDir:docRoot andPort:12345];
    
    //如果不定制上传结果，可以不设置代理
    _webSocket.delegate = self;
    
    //启动Http Server
    [_webSocket start];
}

//可选的代理方法，用于定制上传结果的显示。如果不实现则按默认方式显示上传结果
//fileName:上传的文件名
//success:YES上传成功；NO存在同名的文件上传失败
- (NSString *)lwwebSocketPrintUploadResultForFile:(NSString *)fileName success:(NSNumber *)success
{
    if ([success isEqual:@YES]) {
        return [NSString stringWithFormat:@"%@ success<br>", fileName];
    }
    return [NSString stringWithFormat:@"%@ already exists<br>", fileName];
}

//查看上传的文件列表
- (IBAction)onButtonClicked:(id)sender {
    NSArray *uploadedFiles = [_webSocket allUploadedFiles];
    NSLog(@"%@", uploadedFiles);
}

//删除所有上传的文件
- (IBAction)onButtonCleanClicked:(id)sender {
    [_webSocket clean];
}

@end
