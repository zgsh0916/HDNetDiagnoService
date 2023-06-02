//
//  HDSimplePing.h
//  fffff
//
//  Created by m w on 2023/5/29.
//  Copyright © 2023 hundun. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <AssertMacros.h>
#if TARGET_OS_EMBEDDED || TARGET_IPHONE_SIMULATOR
#import <CFNetwork/CFNetwork.h>
#else
#import <CoreServices/CoreServices.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@protocol HDSimplePingDelegate;

typedef NS_ENUM(NSInteger, SimplePingAddressStyle) {
    SimplePingAddressStyleAny,///IPv4 or IPv6
    SimplePingAddressStyleICMPv4,
    SimplePingAddressStyleICMPv6
};

@interface HDSimplePing : NSObject
///禁用
- (instancetype)init NS_UNAVAILABLE;

///告诉外部调用者，无论调用哪种初始化方法，最终，都会调用 designed initializer
- (instancetype)initWithHostName:(NSString *)hostName NS_DESIGNATED_INITIALIZER;

@property (readonly, nonatomic, copy) NSString *hostName;

@property (readwrite, nonatomic, weak, nullable) id<HDSimplePingDelegate>delegate;

@property (readwrite, nonatomic, assign) SimplePingAddressStyle addressStyle;

@property (readonly, nonatomic, copy, nullable) NSData *hostAddress;

@property (readonly, nonatomic, assign) sa_family_t hostAddressFamily;

@property (readonly, nonatomic, assign) uint16_t identifier;

@property (readonly, nonatomic, assign) uint16_t nextSequenceNumber;

- (void)start;

- (void)sendPingWithData:(NSData *_Nullable)data;

- (void)stop;

#pragma mark - tofix support IPV6
+ (const struct ICMPHeader *)icmpInPacket:(NSData *)packet;

@end

@protocol HDSimplePingDelegate <NSObject>
@optional

- (void)simplePing:(HDSimplePing *)pinger didStartWithAddress:(NSData *)address;

- (void)simplePing:(HDSimplePing *)pinger didFailWithError:(NSError *)error;

- (void)simplePing:(HDSimplePing *)pinger didSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber;

- (void)simplePing:(HDSimplePing *)pinger didFailToSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber error:(NSError *)error;

- (void)simplePing:(HDSimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber;

- (void)simplePing:(HDSimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet;

@end

///结构体
struct ICMPHeader {
    uint8_t type;
    uint8_t code;
    uint16_t checksum;
    uint16_t identifier;
    uint16_t sequenceNumber;
};

typedef struct ICMPHeader ICMPHeader;

__Check_Compile_Time(sizeof(ICMPHeader) == 8);
__Check_Compile_Time(offsetof(ICMPHeader, type) == 0);
__Check_Compile_Time(offsetof(ICMPHeader, code) == 1);
__Check_Compile_Time(offsetof(ICMPHeader, checksum) == 2);
__Check_Compile_Time(offsetof(ICMPHeader, identifier) == 4);
__Check_Compile_Time(offsetof(ICMPHeader, sequenceNumber) == 6);

enum {
    ICMPv4TypeEchoRequest = 8,
    ICMPv4TypeEchoReply   = 0
};

enum {
    ICMPv6TypeEchoRequest = 128,
    ICMPv6TypeEchoReply   = 129
};


NS_ASSUME_NONNULL_END
