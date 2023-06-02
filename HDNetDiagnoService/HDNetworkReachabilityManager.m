//
//  HDNetworkReachabilityManager.m
//  fffff
//
//  Created by m w on 2023/5/29.
//

#import "HDNetworkReachabilityManager.h"
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>

NSString * const HDNetworkingReachabilityDidChangeNotification = @"com.hundun.networking.reachability.change";
NSString * const HDNetworkingReachabilityNotificationStatusItem = @"HDNetworkingReachabilityNotificationStatusItem";

typedef void (^HDNetworkReachabilityStatusBlock)(HDNetworkReachabilityStatus status);
typedef HDNetworkReachabilityManager * (^HDNetworkReachabilityStatusCallback)(HDNetworkReachabilityStatus status);
NSString * WMStringFromNetworkReachabilityStatus(HDNetworkReachabilityStatus status) {
    switch (status) {
        case HDNetworkReachabilityStatusNotReachable:
            return NSLocalizedStringFromTable(@"Not Reachable", @"HDNetworking", nil);
        case HDNetworkReachabilityStatusReachableViaWWAN:
            return NSLocalizedStringFromTable(@"Reachable via WWAN", @"HDNetworking", nil);
        case HDNetworkReachabilityStatusReachableViaWiFi:
            return NSLocalizedStringFromTable(@"Reachable via WiFi", @"HDNetworking", nil);
        case HDNetworkReachabilityStatusUnknown:
        default:
            return NSLocalizedStringFromTable(@"Unkonwn", @"HDNetworking", nil);
    }
}

///获取当前网络状态
static HDNetworkReachabilityStatus HDNetworkReachabilityStatusForFlags(SCNetworkReachabilityFlags flags) {
    BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
    BOOL needsConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
    BOOL canConnectionAutomatically = (((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0) || ((flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0));
    BOOL canConnectWithoutUserInteraction = (canConnectionAutomatically && (flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0);
    BOOL isNetworkReachable = (isReachable && (!needsConnection || canConnectWithoutUserInteraction));
    ///申明一个状态默认是未知类型
    HDNetworkReachabilityStatus status = HDNetworkReachabilityStatusUnknown;
    if (isNetworkReachable == NO) {
        status = HDNetworkReachabilityStatusNotReachable;
    }else if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
        status = HDNetworkReachabilityStatusReachableViaWWAN;
    }else {
        status = HDNetworkReachabilityStatusReachableViaWiFi;
    }
    return status;
}

static void WMPostReachabilityStatusChange(SCNetworkReachabilityFlags flags, HDNetworkReachabilityStatusCallback block) {
    HDNetworkReachabilityStatus status = HDNetworkReachabilityStatusForFlags(flags);
    dispatch_async(dispatch_get_main_queue(), ^{
        HDNetworkReachabilityManager *manager = nil;
        if (block) {
            manager = block(status);
        }
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        NSDictionary *userInfo = @{HDNetworkingReachabilityNotificationStatusItem : @(status)};
        [notificationCenter postNotificationName:HDNetworkingReachabilityDidChangeNotification object:manager userInfo:userInfo];
    });
}

static void HDNetworkReachabilityCallback(SCNetworkReachabilityRef __unused target,SCNetworkReachabilityFlags flags,void *info) {
    WMPostReachabilityStatusChange(flags, (__bridge  HDNetworkReachabilityStatusCallback)info);
}

static const void * HDNetworkReachabilityRetainCallback(const void *info) {
    return Block_copy(info);
}

static void HDNetworkReachabilityReleaseCallback(const void *info) {
    if (info) {
        Block_release(info);
    }
}

@interface HDNetworkReachabilityManager ()
@property (readonly, nonatomic, assign) SCNetworkReachabilityRef networkReachability;
@property (readwrite, nonatomic, assign) HDNetworkReachabilityStatus networkReachabilityStatus;
@property (readwrite, nonatomic, copy) HDNetworkReachabilityStatusBlock networkReachabilityStatusBlock;

@end

@implementation HDNetworkReachabilityManager

+ (instancetype)sharedManager {
    static HDNetworkReachabilityManager *_sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [self manager];
    });
    return _sharedManager;
}

+ (instancetype)managerForDomain:(NSString *)domain {
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [domain UTF8String]);
    HDNetworkReachabilityManager *manager = [[self alloc] initWithReachability:reachability];
    CFRelease(reachability);
    return manager;
}

+ (instancetype)managerForAddress:(const void *)address {
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)address);
    HDNetworkReachabilityManager *manager = [[self alloc] initWithReachability:reachability];
    CFRelease(reachability);
    return manager;
}

+ (instancetype)manager {
    struct sockaddr_in6 address;
    bzero(&address, sizeof(address));
    address.sin6_len = sizeof(address);
    address.sin6_family = AF_INET6;
    return [self managerForAddress:&address];
}

- (instancetype)initWithReachability:(SCNetworkReachabilityRef)reachability {
    if (self = [super init]) {
        _networkReachability = CFRetain(reachability);
        self.networkReachabilityStatus = HDNetworkReachabilityStatusUnknown;
    }
    return self;
}

- (instancetype)init {
    @throw [NSException exceptionWithName:NSGenericException reason:@"`-init` unavailable. Use `-initWithReachability:` instead" userInfo:nil];
    return nil;
}

- (void)dealloc {
    [self stopMonitoring];
    if (_networkReachability != NULL) {
        CFRelease(_networkReachability);
    }
}

- (BOOL)isReachable {
    return [self isReachableViaWWAN] || [self isReachableViaWiFi];
}

- (BOOL)isReachableViaWWAN {
    return self.networkReachabilityStatus == HDNetworkReachabilityStatusReachableViaWWAN;
}

- (BOOL)isReachableViaWiFi {
    return self.networkReachabilityStatus == HDNetworkReachabilityStatusReachableViaWiFi;
}

- (void)startMonitoring {
    [self stopMonitoring];
    if (!self.networkReachability) {
        return;
    };
    __weak typeof(self) weakSelf = self;
    HDNetworkReachabilityStatusCallback callback = ^(HDNetworkReachabilityStatus status) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.networkReachabilityStatus = status;
        if (strongSelf.networkReachabilityStatusBlock) {
            strongSelf.networkReachabilityStatusBlock(status);
        }
        return strongSelf;
    };
    SCNetworkReachabilityContext context = {0, (__bridge  void *)callback, HDNetworkReachabilityRetainCallback, HDNetworkReachabilityReleaseCallback, NULL};
    SCNetworkReachabilitySetCallback(self.networkReachability, HDNetworkReachabilityCallback, &context);
    SCNetworkReachabilityScheduleWithRunLoop(self.networkReachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        SCNetworkReachabilityFlags flags;
        if (SCNetworkReachabilityGetFlags(self.networkReachability, &flags)) {
            WMPostReachabilityStatusChange(flags, callback);
        }
    });
}

- (void)stopMonitoring {
    if (!self.networkReachability) {
        return;
    }
    SCNetworkReachabilityUnscheduleFromRunLoop(self.networkReachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
}

- (NSString *)localizedNetworkReachabilityStatusString {
    return WMStringFromNetworkReachabilityStatus(self.networkReachabilityStatus);
}

- (void)setReachabilityStatusChangeBlock:(void (^)(HDNetworkReachabilityStatus))block {
    self.networkReachabilityStatusBlock = block;
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    if ([key isEqualToString:@"reachable"] || [key isEqualToString:@"reachableViaWWAN"] || [key isEqualToString:@"reachableViaWiFi"]) {
        return [NSSet setWithObject:@"networkReachabilityStatus"];
    }
    return [super keyPathsForValuesAffectingValueForKey:key];
}

@end

