//
//  HDNetConnect.h
//  HDNetDiagnoServiceDemo
//
//  Created by m w on 2023/5/29.
//  Copyright © 2023 hundun. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 * @protocal HDNetConnectDelegate监测connect命令的的输出到日志变量；
 *
 */
@protocol HDNetConnectDelegate <NSObject>
- (void)appendSocketLog:(NSString *)socketLog;
- (void)connectDidEnd:(BOOL)success;
@end


/*
 * @class LDNetConnect ping监控
 * 主要是通过建立socket连接的过程，监控目标主机是否连通
 * 连续执行五次，因为每次的速度不一致，可以观察其平均速度来判断网络情况
 */
@interface HDNetConnect : NSObject {
}

@property (nonatomic, weak) id<HDNetConnectDelegate> delegate;

/**
 * 通过hostaddress和port 进行connect诊断
 */
- (void)runWithHostAddress:(NSString *)hostAddress port:(int)port;

/**
 * 停止connect
 */
- (void)stopConnect;

@end
