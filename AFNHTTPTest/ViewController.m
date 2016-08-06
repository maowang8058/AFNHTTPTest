//
//  ViewController.m
//  AFNTest
//
//  Created by 毛旺 on 16/8/4.
//  Copyright © 2016年 毛旺. All rights reserved.
//

#import "ViewController.h"
#import "AFNetworking.h"
#import <objc/runtime.h>

#define CACHE_PATH [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"cacheFile"]
#define STORE_PATH(name) [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:name]

@interface ViewController ()

@property(nonatomic,strong)NSURLSessionDownloadTask * downLoadTask;
@property(nonatomic,strong)NSData *resumeData;

@end

@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(handleApplicationExited) name:@"applications_exited" object:nil];
    
    UIButton *pauseBtn=[[UIButton alloc]initWithFrame:CGRectMake(100, 200, 100, 100)];
    [pauseBtn addTarget:self action:@selector(pauseDownload) forControlEvents:UIControlEventTouchUpInside];
    [pauseBtn setTitle:@"暂停" forState:UIControlStateNormal];
    pauseBtn.backgroundColor=[UIColor redColor];
    [self.view addSubview:pauseBtn];
    
    UIButton *startBtn=[[UIButton alloc]initWithFrame:CGRectMake(100, 300, 100, 100)];
    [startBtn addTarget:self action:@selector(startDownload) forControlEvents:UIControlEventTouchUpInside];
    [startBtn setTitle:@"开始" forState:UIControlStateNormal];
    startBtn.backgroundColor=[UIColor grayColor];
    [self.view addSubview:startBtn];
    
    
}

-(void)startDownload
{
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://down.ffxia.com/avi/405.avi"] cachePolicy:1 timeoutInterval:60];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.resumeData=[NSData dataWithContentsOfFile:CACHE_PATH];
    AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc]initWithSessionConfiguration:configuration];
    
    if (self.resumeData&&self.resumeData.length>0)
    { // 如果是之前被暂停的任务，就从已经保存的数据恢复下载
        
        self.downLoadTask = [manager downloadTaskWithResumeData:self.resumeData progress:^(NSProgress * _Nonnull downloadProgress) {
            
            NSLog(@"downloadProgress----%f",1.0 * downloadProgress.completedUnitCount / downloadProgress.totalUnitCount);
            
        } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            
            NSLog(@"targetPath----%@", targetPath);
            
            BOOL isDrect = YES;
            NSError *error;
            NSFileManager  *fileManger = [NSFileManager defaultManager];
            if ([fileManger fileExistsAtPath:CACHE_PATH isDirectory:&isDrect])
            {
                [fileManger removeItemAtPath:CACHE_PATH error:&error];
            }
            
            return [NSURL fileURLWithPath:STORE_PATH(response.suggestedFilename) isDirectory:NO];
            
        } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
            if(!error)NSLog(@"下载完成");
        }];
        
        [self.downLoadTask resume];
        
    }
    else
    {
        self.downLoadTask=[manager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
            
            NSLog(@"downloadProgress----%f",1.0 * downloadProgress.completedUnitCount / downloadProgress.totalUnitCount);
            
        } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            
            NSLog(@"targetPath----%@", targetPath);
            
            return [NSURL fileURLWithPath:STORE_PATH(response.suggestedFilename) isDirectory:NO];
            
        } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
            if(!error)NSLog(@"下载完成");
        }];
        
        self.resumeData=nil;
        [self.downLoadTask resume];
    }
}
-(void)pauseDownload
{
    [self.downLoadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        self.resumeData = resumeData;
        self.downLoadTask = nil;
        [resumeData writeToFile:CACHE_PATH atomically:YES];
    }];
}


//程序中断处理
-(void)handleApplicationExited
{
    if(self.downLoadTask&&self.downLoadTask.state==0)
    {
        unsigned int outCount, i;
        objc_property_t *properties = class_copyPropertyList([self.downLoadTask class], &outCount);
        for (i = 0; i<outCount; i++)
        {
            objc_property_t property = properties[i];
            const char* char_f =property_getName(property);
            NSString *propertyName = [NSString stringWithUTF8String:char_f];
            
            if ([@"downloadFile" isEqualToString:propertyName])
            {
                id propertyValue = [self.downLoadTask valueForKey:(NSString *)propertyName];
                unsigned int downloadFileoutCount, downloadFileIndex;
                objc_property_t *downloadFileproperties = class_copyPropertyList([propertyValue class], &downloadFileoutCount);
                for (downloadFileIndex = 0; downloadFileIndex < downloadFileoutCount; downloadFileIndex++)
                {
                    objc_property_t downloadFileproperty = downloadFileproperties[downloadFileIndex];
                    const char* downloadFilechar_f =property_getName(downloadFileproperty);
                    NSString *downloadFilepropertyName = [NSString stringWithUTF8String:downloadFilechar_f];
                    if([@"path" isEqualToString:downloadFilepropertyName])
                    {
                        
                        NSString *downloadFilePath = [propertyValue valueForKey:(NSString *)downloadFilepropertyName];
                        NSData *downloadFilepropertyValue=[NSData dataWithContentsOfFile:downloadFilePath];
                        
                        NSMutableDictionary *plistDict=[NSMutableDictionary dictionary];
                        NSMutableURLRequest *newResumeRequest =[NSMutableURLRequest requestWithURL:self.downLoadTask.currentRequest.URL];
                        [newResumeRequest addValue:[NSString stringWithFormat:@"bytes=%ld-",downloadFilepropertyValue.length] forHTTPHeaderField:@"Range"];
                        NSData *newResumeRequestData = [NSKeyedArchiver archivedDataWithRootObject:newResumeRequest];
                        
                        [plistDict setObject:[NSNumber numberWithInteger:downloadFilepropertyValue.length] forKey:@"NSURLSessionResumeBytesReceived"];
                        [plistDict setObject:newResumeRequestData forKey:@"NSURLSessionResumeCurrentRequest"];
                        [plistDict setObject:[downloadFilePath lastPathComponent] forKey:@"NSURLSessionResumeInfoTempFileName"];
                        NSData *newResumeData=[NSPropertyListSerialization dataWithPropertyList:plistDict format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
                        
                        [newResumeData writeToFile:CACHE_PATH atomically:YES];
                        
                        
                        break;
                    }
                }
                free(downloadFileproperties);
            }
            else
            {
                continue;
            }
        }
        free(properties);
    }
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
