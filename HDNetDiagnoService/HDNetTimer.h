//
//  HDNetTimer.h
//  fffff
//
//  Created by m w on 2023/5/29.
//  Copyright © 2023 hundun. All rights reserved.
//

#import <Foundation/Foundation.h>
 
NS_ASSUME_NONNULL_BEGIN

@interface HDNetTimer : NSObject

/// 微秒
+ (long)getMicroSeconds;

///用时间戳和参数来计算每毫秒的时间
+ (long)computeDurationSince:(long)uTime;

@end

NS_ASSUME_NONNULL_END
