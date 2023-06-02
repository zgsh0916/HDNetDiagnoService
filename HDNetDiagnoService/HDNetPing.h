//
//  HDNetPing.h
//  fffff
//
//  Created by m w on 2023/5/30.
//  Copyright © 2023 hundun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HDSimplePing.h"

@protocol HDNetPingDelegate <NSObject>

- (void)appendPingLog:(NSString *_Nullable)pingLog;

- (void)netPingDidEnd;

@end
NS_ASSUME_NONNULL_BEGIN

@interface HDNetPing : NSObject

@property (nonatomic, weak) id<HDNetPingDelegate>delegate;

///通过hostname 进行ping诊断
- (void)runWithHostName:(NSString *)hostName normalPing:(BOOL)normalPing;

///停止ping
- (void)stopPing;

@end

NS_ASSUME_NONNULL_END
