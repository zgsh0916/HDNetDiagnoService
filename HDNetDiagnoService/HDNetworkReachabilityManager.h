//
//  HDNetworkReachabilityManager.h
//  fffff
//
//  Created by m w on 2023/5/29.
//


#import <Foundation/Foundation.h>

#import <SystemConfiguration/SystemConfiguration.h>
//网络状态的枚举
typedef NS_ENUM(NSInteger,HDNetworkReachabilityStatus) {
    HDNetworkReachabilityStatusUnknown           = -1,//未知
    HDNetworkReachabilityStatusNotReachable      = 0,//不可用
    HDNetworkReachabilityStatusReachableViaWWAN = 1,//蜂窝网络
    HDNetworkReachabilityStatusReachableViaWiFi  = 2 //Wi-Fi
};

NS_ASSUME_NONNULL_BEGIN

@interface HDNetworkReachabilityManager : NSObject

///当前网络的状态
@property (readonly, nonatomic, assign) HDNetworkReachabilityStatus networkReachabilityStatus;

///当前网络是否可用
@property (readonly, nonatomic, assign, getter = isReachable) BOOL reachable;

///当前网络是否是蜂窝
@property (readonly, nonatomic, assign, getter = isReachableViaWWAN) BOOL reachableViaWWAN;

///当前网络是否是WiFi
@property (readonly, nonatomic, assign, getter = isReachableViaWiFi) BOOL reachableViaWiFi;

///---------------------
/// @name Initialization
///---------------------

///初始化单例
+ (instancetype)sharedManager;

///创建并返回具有默认 socket 地址的 AFNetworkReachabilityManager 对象，主动监视默认的 socket 地址
+ (instancetype)manager;

///创建并返回指定域的 AFNetworkReachabilityManager 对象，主动监视指定域的网络状态
+ (instancetype)managerForDomain:(NSString *)domain;

///创建并返回指定 socket 地址的 AFNetworkReachabilityManager 对象，主动监视指定的 socket 地址
+ (instancetype)managerForAddress:(const void *)address;

///创建并返回一个用指定的 SCNetworkReachabilityRef 对象初始化的 AFNetworkReachabilityManager 对象，主动监视指定的可达性。
- (instancetype)initWithReachability:(SCNetworkReachabilityRef)reachability;

///禁用系统初始化方法 new init
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)init NS_UNAVAILABLE;

///--------------------------------------------------
/// @name 开始 & 停止 Reachability Monitoring
///--------------------------------------------------

///开始监听网络可达状态
- (void)startMonitoring;

///停止监听网络可达状态
- (void)stopMonitoring;

///-------------------------------------------------
/// @name 获取 本土化 网络状态描述
///-------------------------------------------------
///返回一个本土化当前网络状态描述
- (NSString *)localizedNetworkReachabilityStatusString;

///---------------------------------------------------
/// @name 设置网络可达性状态变化回调
///---------------------------------------------------
- (void)setReachabilityStatusChangeBlock:(nullable void (^)(HDNetworkReachabilityStatus))block;

@end

///--------------------
/// @name Notifications
///--------------------

///FOUNDATION_EXPORT和#define使用一样，前者可以==来判断，后者则是isequalString
FOUNDATION_EXPORT NSString * const HDNetworkingReachabilityDidChangeNotification;
FOUNDATION_EXPORT NSString * const HDNetworkingReachabilityNotificationStatusItem;

///--------------------
/// @name Functions
///--------------------
///返回一个本土化网络状态描述
FOUNDATION_EXPORT NSString *WMStringFromNetworkReachabilityStatus(HDNetworkReachabilityStatus ststus);

NS_ASSUME_NONNULL_END


