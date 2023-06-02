//
//  HDSimplePing.m
//  fffff
//
//  Created by m w on 2023/5/29.
//  Copyright © 2023 hundun. All rights reserved.
//

#import "HDSimplePing.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <errno.h>

#pragma mark * IPv4 and ICMPv4 On-The-Wire Format

struct IPv4Header {
    uint8_t     versionAndHeaderLength;
    uint8_t     differentiatedServices;
    uint16_t    totalLength;
    uint16_t    identification;
    uint16_t    flagsAndFragmentOffset;
    uint8_t     timeToLive;
    uint8_t     protocol;
    uint16_t    headerChecksum;
    uint8_t     sourceAddress[4];
    uint8_t     destinationAddress[4];
};
typedef struct IPv4Header IPv4Header;

__Check_Compile_Time(sizeof(IPv4Header) == 20);
__Check_Compile_Time(offsetof(IPv4Header, versionAndHeaderLength) == 0);
__Check_Compile_Time(offsetof(IPv4Header, differentiatedServices) == 1);
__Check_Compile_Time(offsetof(IPv4Header, totalLength) == 2);
__Check_Compile_Time(offsetof(IPv4Header, identification) == 4);
__Check_Compile_Time(offsetof(IPv4Header, flagsAndFragmentOffset) == 6);
__Check_Compile_Time(offsetof(IPv4Header, timeToLive) == 8);
__Check_Compile_Time(offsetof(IPv4Header, protocol) == 9);
__Check_Compile_Time(offsetof(IPv4Header, headerChecksum) == 10);
__Check_Compile_Time(offsetof(IPv4Header, sourceAddress) == 12);
__Check_Compile_Time(offsetof(IPv4Header, destinationAddress) == 16);


static uint16_t in_cksum(const void *buffer, size_t bufferLen) {
    //
    size_t              bytesLeft;
    int32_t             sum;
    const uint16_t *    cursor;
    union {
        uint16_t        us;
        uint8_t         uc[2];
    } last;
    uint16_t            answer;
    
    bytesLeft = bufferLen;
    sum = 0;
    cursor = buffer;
    
    while (bytesLeft > 1) {
        sum += *cursor;
        cursor += 1;
        bytesLeft -= 2;
    }
    
    if (bytesLeft == 1) {
        last.uc[0] = * (const uint8_t *) cursor;
        last.uc[1] = 0;
        sum += last.us;
    }
    
    /* add back carry outs from top 16 bits to low 16 bits */
    sum = (sum >> 16) + (sum & 0xffff);    /* add hi 16 to low 16 */
    sum += (sum >> 16);            /* add carry */
    answer = (uint16_t) ~sum;   /* truncate to 16 bits */
    
    return answer;
}

#pragma mark * SimplePing

@interface HDSimplePing ()

@property (nonatomic, copy, readwrite, nullable) NSData *hostAddress;
@property (nonatomic, assign, readwrite) uint16_t nextSequenceNumber;

@property (nonatomic, assign, readwrite)           BOOL         nextSequenceNumberHasWrapped;

@property (nonatomic, strong, readwrite, nullable) CFHostRef host __attribute__ ((NSObject));

@property (nonatomic, strong, readwrite, nullable) CFSocketRef socket __attribute__ ((NSObject));

@end


@implementation HDSimplePing

- (instancetype)initWithHostName:(NSString *)hostName {
    NSParameterAssert(hostName != nil);
    self = [super init];
    if (self != nil) {
        self->_hostName   = [hostName copy];
        self->_identifier = (uint16_t) arc4random();
    }
    return self;
}

- (void)dealloc {
    [self stop];
    // Double check that -stop took care of _host and _socket.
    assert(self->_host == NULL);
    assert(self->_socket == NULL);
}

- (sa_family_t)hostAddressFamily {
    sa_family_t     result;
    
    result = AF_UNSPEC;
    if ( (self.hostAddress != nil) && (self.hostAddress.length >= sizeof(struct sockaddr)) ) {
        result = ((const struct sockaddr *) self.hostAddress.bytes)->sa_family;
    }
    return result;
}

/*! Shuts down the pinger object and tell the delegate about the error.
 *  \param error Describes the failure.
 */

- (void)didFailWithError:(NSError *)error {
    id<HDSimplePingDelegate>  strongDelegate;
    assert(error != nil);
    CFAutorelease( CFBridgingRetain( self ));
    
    [self stop];
    strongDelegate = self.delegate;
    if ( (strongDelegate != nil) && [strongDelegate respondsToSelector:@selector(simplePing:didFailWithError:)] ) {
        [strongDelegate simplePing:self didFailWithError:error];
    }
}

- (void)didFailWithHostStreamError:(CFStreamError)streamError {
    NSDictionary *  userInfo;
    NSError *       error;
    
    if (streamError.domain == kCFStreamErrorDomainNetDB) {
        userInfo = @{(id) kCFGetAddrInfoFailureKey: @(streamError.error)};
    } else {
        userInfo = nil;
    }
    error = [NSError errorWithDomain:(NSString *) kCFErrorDomainCFNetwork code:kCFHostErrorUnknown userInfo:userInfo];
    
    [self didFailWithError:error];
}

- (NSData *)pingPacketWithType:(uint8_t)type payload:(NSData *)payload requiresChecksum:(BOOL)requiresChecksum {
    NSMutableData *         packet;
    ICMPHeader *            icmpPtr;
    
    packet = [NSMutableData dataWithLength:sizeof(*icmpPtr) + payload.length];
    assert(packet != nil);
    
    icmpPtr = packet.mutableBytes;
    icmpPtr->type = type;
    icmpPtr->code = 0;
    icmpPtr->checksum = 0;
    icmpPtr->identifier     = OSSwapHostToBigInt16(self.identifier);
    icmpPtr->sequenceNumber = OSSwapHostToBigInt16(self.nextSequenceNumber);
    memcpy(&icmpPtr[1], [payload bytes], [payload length]);
    
    if (requiresChecksum) {
        
        icmpPtr->checksum = in_cksum(packet.bytes, packet.length);
    }
    
    return packet;
}

/**
 * 通过ping的套接口发送数据
 */
- (void)sendPingWithData:(NSData *_Nullable)data {
    int                     err;
    NSData *                payload;
    NSData *                packet;
    ssize_t                 bytesSent;
    id<HDSimplePingDelegate>  strongDelegate;
    
    NSParameterAssert(self.hostAddress != nil);     // gotta wait for -simplePing:didStartWithAddress:
    
    payload = data;
    if (payload == nil) {
        payload = [[NSString stringWithFormat:@"%28zd bottles of beer on the wall", (ssize_t) 99 - (size_t) (self.nextSequenceNumber % 100) ] dataUsingEncoding:NSASCIIStringEncoding];
        assert(payload != nil);
        
        assert([payload length] == 56);
    }
    
    switch (self.hostAddressFamily) {
        case AF_INET: {
            packet = [self pingPacketWithType:ICMPv4TypeEchoRequest payload:payload requiresChecksum:YES];
        } break;
        case AF_INET6: {
            packet = [self pingPacketWithType:ICMPv6TypeEchoRequest payload:payload requiresChecksum:NO];
        } break;
        default: {
            assert(NO);
        } break;
    }
    assert(packet != nil);
    
    if (self.socket == NULL) {
        bytesSent = -1;
        err = EBADF;
    } else {
        bytesSent = sendto(
                           CFSocketGetNative(self.socket),
                           packet.bytes,
                           packet.length,
                           0,
                           self.hostAddress.bytes,
                           (socklen_t) self.hostAddress.length
                           );
        err = 0;
        if (bytesSent < 0) {
            err = errno;
        }
    }
    
    strongDelegate = self.delegate;
    if ( (bytesSent > 0) && (((NSUInteger) bytesSent) == packet.length) ) {
        
        if ( (strongDelegate != nil) && [strongDelegate respondsToSelector:@selector(simplePing:didSendPacket:sequenceNumber:)] ) {
            [strongDelegate simplePing:self didSendPacket:packet sequenceNumber:self.nextSequenceNumber];
        }
    } else {
        NSError *   error;
        
        if (err == 0) {
            err = ENOBUFS;
        }
        error = [NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil];
        if ( (strongDelegate != nil) && [strongDelegate respondsToSelector:@selector(simplePing:didFailToSendPacket:sequenceNumber:error:)] ) {
            [strongDelegate simplePing:self didFailToSendPacket:packet sequenceNumber:self.nextSequenceNumber error:error];
        }
    }
    
    self.nextSequenceNumber += 1;
    if (self.nextSequenceNumber == 0) {
        self.nextSequenceNumberHasWrapped = YES;
    }
}


+ (NSUInteger)icmpHeaderOffsetInIPv4Packet:(NSData *)packet {
    
    NSUInteger                  result;
    const struct IPv4Header *   ipPtr;
    size_t                      ipHeaderLength;
    
    result = NSNotFound;
    if (packet.length >= (sizeof(IPv4Header) + sizeof(ICMPHeader))) {
        ipPtr = (const IPv4Header *) packet.bytes;
        if ( ((ipPtr->versionAndHeaderLength & 0xF0) == 0x40) &&            // IPv4
            ( ipPtr->protocol == IPPROTO_ICMP ) ) {
            ipHeaderLength = (ipPtr->versionAndHeaderLength & 0x0F) * sizeof(uint32_t);
            if (packet.length >= (ipHeaderLength + sizeof(ICMPHeader))) {
                result = ipHeaderLength;
            }
        }
    }
    return result;
}


- (BOOL)validateSequenceNumber:(uint16_t)sequenceNumber {
    if (self.nextSequenceNumberHasWrapped) {
        
        return ((uint16_t) (self.nextSequenceNumber - sequenceNumber)) < (uint16_t) 120;
    } else {
        return sequenceNumber < self.nextSequenceNumber;
    }
}


- (BOOL)validatePing4ResponsePacket:(NSMutableData *)packet sequenceNumber:(uint16_t *)sequenceNumberPtr {
    BOOL                result;
    NSUInteger          icmpHeaderOffset;
    ICMPHeader *        icmpPtr;
    uint16_t            receivedChecksum;
    uint16_t            calculatedChecksum;
    
    result = NO;
    
    icmpHeaderOffset = [[self class] icmpHeaderOffsetInIPv4Packet:packet];
    if (icmpHeaderOffset != NSNotFound) {
        icmpPtr = (struct ICMPHeader *) (((uint8_t *) packet.mutableBytes) + icmpHeaderOffset);
        
        receivedChecksum   = icmpPtr->checksum;
        icmpPtr->checksum  = 0;
        calculatedChecksum = in_cksum(icmpPtr, packet.length - icmpHeaderOffset);
        icmpPtr->checksum  = receivedChecksum;
        
        if (receivedChecksum == calculatedChecksum) {
            if ( (icmpPtr->type == ICMPv4TypeEchoReply) && (icmpPtr->code == 0) ) {
                if ( OSSwapBigToHostInt16(icmpPtr->identifier) == self.identifier ) {
                    uint16_t    sequenceNumber;
                    
                    sequenceNumber = OSSwapBigToHostInt16(icmpPtr->sequenceNumber);
                    if ([self validateSequenceNumber:sequenceNumber]) {
                        
                        // Remove the IPv4 header off the front of the data we received, leaving us with
                        // just the ICMP header and the ping payload.
                        [packet replaceBytesInRange:NSMakeRange(0, icmpHeaderOffset) withBytes:NULL length:0];
                        
                        *sequenceNumberPtr = sequenceNumber;
                        result = YES;
                    }
                }
            }
        }
    }
    
    return result;
}

- (BOOL)validatePing6ResponsePacket:(NSMutableData *)packet sequenceNumber:(uint16_t *)sequenceNumberPtr {
    BOOL                    result;
    const ICMPHeader *      icmpPtr;
    
    result = NO;
    
    if (packet.length >= sizeof(*icmpPtr)) {
        icmpPtr = packet.bytes;
        
        if ( (icmpPtr->type == ICMPv6TypeEchoReply) && (icmpPtr->code == 0) ) {
            if ( OSSwapBigToHostInt16(icmpPtr->identifier) == self.identifier ) {
                uint16_t    sequenceNumber;
                
                sequenceNumber = OSSwapBigToHostInt16(icmpPtr->sequenceNumber);
                if ([self validateSequenceNumber:sequenceNumber]) {
                    *sequenceNumberPtr = sequenceNumber;
                    result = YES;
                }
            }
        }
    }
    return result;
}

- (BOOL)validatePingResponsePacket:(NSMutableData *)packet sequenceNumber:(uint16_t *)sequenceNumberPtr {
    BOOL        result;
    
    switch (self.hostAddressFamily) {
        case AF_INET: {
            result = [self validatePing4ResponsePacket:packet sequenceNumber:sequenceNumberPtr];
        } break;
        case AF_INET6: {
            result = [self validatePing6ResponsePacket:packet sequenceNumber:sequenceNumberPtr];
        } break;
        default: {
            assert(NO);
            result = NO;
        } break;
    }
    return result;
}

- (void)readData {
    int                     err;
    struct sockaddr_storage addr;
    socklen_t               addrLen;
    ssize_t                 bytesRead;
    void *                  buffer;
    enum { kBufferSize = 65535 };
    
    buffer = malloc(kBufferSize);
    assert(buffer != NULL);
    
    addrLen = sizeof(addr);
    bytesRead = recvfrom(CFSocketGetNative(self.socket), buffer, kBufferSize, 0, (struct sockaddr *) &addr, &addrLen);
    err = 0;
    if (bytesRead < 0) {
        err = errno;
    }
    
    if (bytesRead > 0) {
        NSMutableData *         packet;
        id<HDSimplePingDelegate>  strongDelegate;
        uint16_t                sequenceNumber;
        
        packet = [NSMutableData dataWithBytes:buffer length:(NSUInteger) bytesRead];
        assert(packet != nil);
        
        strongDelegate = self.delegate;
        if ( [self validatePingResponsePacket:packet sequenceNumber:&sequenceNumber] ) {
            if ( (strongDelegate != nil) && [strongDelegate respondsToSelector:@selector(simplePing:didReceivePingResponsePacket:sequenceNumber:)] ) {
                [strongDelegate simplePing:self didReceivePingResponsePacket:packet sequenceNumber:sequenceNumber];
            }
        } else {
            if ( (strongDelegate != nil) && [strongDelegate respondsToSelector:@selector(simplePing:didReceiveUnexpectedPacket:)] ) {
                [strongDelegate simplePing:self didReceiveUnexpectedPacket:packet];
            }
        }
    } else {
        
        if (err == 0) {
            err = EPIPE;
        }
        [self didFailWithError:[NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil]];
    }
    
    free(buffer);
    
}

static void SocketReadCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    
    HDSimplePing *    obj;
    
    obj = (__bridge HDSimplePing *) info;
    assert([obj isKindOfClass:[HDSimplePing class]]);
    
#pragma unused(s)
    assert(s == obj.socket);
#pragma unused(type)
    assert(type == kCFSocketReadCallBack);
#pragma unused(address)
    assert(address == nil);
#pragma unused(data)
    assert(data == nil);
    
    [obj readData];
}


- (void)startWithHostAddress {
    int                     err;
    int                     fd;
    
    assert(self.hostAddress != nil);
    
    fd = -1;
    err = 0;
    switch (self.hostAddressFamily) {
        case AF_INET: {
            fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
            if (fd < 0) {
                err = errno;
            }
        } break;
        case AF_INET6: {
            fd = socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6);
            if (fd < 0) {
                err = errno;
            }
        } break;
        default: {
            err = EPROTONOSUPPORT;
        } break;
    }
    
    if (err != 0) {
        [self didFailWithError:[NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil]];
    } else {
        CFSocketContext         context = {0, (__bridge void *)(self), NULL, NULL, NULL};
        CFRunLoopSourceRef      rls;
        id<HDSimplePingDelegate>  strongDelegate;
        
        self.socket = (CFSocketRef) CFAutorelease( CFSocketCreateWithNative(NULL, fd, kCFSocketReadCallBack, SocketReadCallback, &context) );
        assert(self.socket != NULL);
        
        assert( CFSocketGetSocketFlags(self.socket) & kCFSocketCloseOnInvalidate );
        fd = -1;
        
        rls = CFSocketCreateRunLoopSource(NULL, self.socket, 0);
        assert(rls != NULL);
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
        
        CFRelease(rls);
        
        strongDelegate = self.delegate;
        if ( (strongDelegate != nil) && [strongDelegate respondsToSelector:@selector(simplePing:didStartWithAddress:)] ) {
            [strongDelegate simplePing:self didStartWithAddress:self.hostAddress];
        }
    }
    assert(fd == -1);
}


- (void)hostResolutionDone {
    Boolean     resolved;
    NSArray *   addresses;
    
    // Find the first appropriate address.
    
    addresses = (__bridge NSArray *) CFHostGetAddressing(self.host, &resolved);
    if ( resolved && (addresses != nil) ) {
        resolved = false;
        for (NSData * address in addresses) {
            const struct sockaddr * addrPtr;
            
            addrPtr = (const struct sockaddr *) address.bytes;
            if ( address.length >= sizeof(struct sockaddr) ) {
                switch (addrPtr->sa_family) {
                    case AF_INET: {
                        if (self.addressStyle != SimplePingAddressStyleICMPv6) {
                            self.hostAddress = address;
                            resolved = true;
                        }
                    } break;
                    case AF_INET6: {
                        if (self.addressStyle != SimplePingAddressStyleICMPv4) {
                            self.hostAddress = address;
                            resolved = true;
                        }
                    } break;
                }
            }
            if (resolved) {
                break;
            }
        }
    }
    
    // We're done resolving, so shut that down.
    
    [self stopHostResolution];
    
    // If all is OK, start the send and receive infrastructure, otherwise stop.
    
    if (resolved) {
        [self startWithHostAddress];
    } else {
        [self didFailWithError:[NSError errorWithDomain:(NSString *)kCFErrorDomainCFNetwork code:kCFHostErrorHostNotFound userInfo:nil]];
    }
}

/*! The callback for our CFHost object.
 *  \details This simply routes the call to our `-hostResolutionDone` or
 *      `-didFailWithHostStreamError:` methods.
 *  \param theHost See the documentation for CFHostClientCallBack.
 *  \param typeInfo See the documentation for CFHostClientCallBack.
 *  \param error See the documentation for CFHostClientCallBack.
 *  \param info See the documentation for CFHostClientCallBack; this is actually a pointer to
 *      the 'owning' object.
 */

static void HostResolveCallback(CFHostRef theHost, CFHostInfoType typeInfo, const CFStreamError *error, void *info) {
    // This C routine is called by CFHost when the host resolution is complete.
    // It just redirects the call to the appropriate Objective-C method.
    HDSimplePing *    obj;
    
    obj = (__bridge HDSimplePing *) info;
    assert([obj isKindOfClass:[HDSimplePing class]]);
    
#pragma unused(theHost)
    assert(theHost == obj.host);
#pragma unused(typeInfo)
    assert(typeInfo == kCFHostAddresses);
    
    if ( (error != NULL) && (error->domain != 0) ) {
        [obj didFailWithHostStreamError:*error];
    } else {
        [obj hostResolutionDone];
    }
}

/**
 * 开启ping命令
 * 如果用户直接提供了一个ip地址，就可以直接开始执行ping命令
 * 否则需要创建socket获取host
 */

- (void)start {
    Boolean             success;
    CFHostClientContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    CFStreamError       streamError;
    
    assert(self.host == NULL);
    assert(self.hostAddress == nil);
    
    self.host = (CFHostRef) CFAutorelease( CFHostCreateWithName(NULL, (__bridge CFStringRef) self.hostName) );
    assert(self.host != NULL);
    
    CFHostSetClient(self.host, HostResolveCallback, &context);
    
    CFHostScheduleWithRunLoop(self.host, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    
    success = CFHostStartInfoResolution(self.host, kCFHostAddresses, &streamError);
    if ( ! success ) {
        [self didFailWithHostStreamError:streamError];
    }
}

/*! Stops the name-to-address resolution infrastructure.
 */

- (void)stopHostResolution {
    // Shut down the CFHost.
    if (self.host != NULL) {
        CFHostSetClient(self.host, NULL, NULL);
        CFHostUnscheduleFromRunLoop(self.host, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        self.host = NULL;
    }
}

/*! Stops the send and receive infrastructure.
 */

- (void)stopSocket {
    if (self.socket != NULL) {
        CFSocketInvalidate(self.socket);
        self.socket = NULL;
    }
}

- (void)stop {
    [self stopHostResolution];
    [self stopSocket];
    
    // Junk the host address on stop.  If the client calls -start again, we'll
    // re-resolve the host name.
    
    self.hostAddress = NULL;
}


/**
 * IPV4的返回包直接将IPV4的头去掉了
 */
+(const struct ICMPHeader *)icmpInPacket:(NSData *)packet
{
    const struct ICMPHeader *result;
    result = nil;
    
    if (packet.length >= sizeof(*result)) {
        result = packet.bytes;
    }
    
    return result;
}

@end

