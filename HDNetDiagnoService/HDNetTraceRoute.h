//
//  TraceRoute.h
//  HDNetCheckServiceDemo
//
//  Created by m w on 2023/5/29.
//  Copyright © 2023 hundun. All rights reserved.
//

#import <Foundation/Foundation.h>

static const int TRACEROUTE_PORT = 30001;
static const int TRACEROUTE_MAX_TTL = 30;
static const int TRACEROUTE_ATTEMPTS = 3;
static const int TRACEROUTE_TIMEOUT = 5000000;

/*
 * @protocal LDNetTraceRouteDelegate监测TraceRoute命令的的输出到日志变量；
 *
 */
@protocol HDNetTraceRouteDelegate <NSObject>
- (void)appendRouteLog:(NSString *)routeLog;
- (void)traceRouteDidEnd;
@end


/*
 * @class LDNetTraceRoute TraceRoute网络监控
 * 主要是通过模拟shell命令traceRoute的过程，监控网络站点间的跳转
 * 默认执行20转，每转进行三次发送测速
 */
@interface HDNetTraceRoute : NSObject {
    int udpPort;      //执行端口
    int maxTTL;       //执行转数
    int readTimeout;  //每次发送时间的timeout
    int maxAttempts;  //每转的发送次数
    NSString *running;
    bool isrunning;
}

@property (nonatomic, weak) id<HDNetTraceRouteDelegate> delegate;

/**
 * 初始化
 */
- (HDNetTraceRoute *)initWithMaxTTL:(int)ttl
                            timeout:(int)timeout
                        maxAttempts:(int)attempts
                               port:(int)port;

/**
 * 监控tranceroute 路径
 */
- (Boolean)doTraceRoute:(NSString *)host;

/**
 * 停止traceroute
 */
- (void)stopTrace;
- (bool)isRunning;

@end
