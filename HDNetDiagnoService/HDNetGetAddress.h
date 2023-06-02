//
//  HDNetGetAddress.h
//  HDNetDiagnoServiceDemo
//
//  Created by m w on 2023/5/29.
//  Copyright © 2023 hundun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface HDNetGetAddress : NSObject

//网络类型
typedef enum {
    NETWORK_TYPE_NONE = 0,
    NETWORK_TYPE_2G = 1,
    NETWORK_TYPE_3G = 2,
    NETWORK_TYPE_4G = 3,
    NETWORK_TYPE_5G = 4, 
    NETWORK_TYPE_WIFI = 5,
} NETWORK_TYPE;

/*!
 * 获取当前设备ip地址
 */
+ (NSString *)deviceIPAdress;


/*!
 * 获取当前设备网关地址
 */
+ (NSString *)getGatewayIPAddress;


/*!
 * 通过域名获取服务器DNS地址
 */
+ (NSArray *)getDNSsWithDormain:(NSString *)hostName;


/*!
 * 获取本地网络的DNS地址
 */
+ (NSArray *)outPutDNSServers;


/*!
 * 获取当前网络类型
 */
+ (NETWORK_TYPE)getNetworkTypeFromStatusBar;

/**
 * 格式化IPV6地址
 */
+(NSString *)formatIPV6Address:(struct in6_addr)ipv6Addr;

@end
