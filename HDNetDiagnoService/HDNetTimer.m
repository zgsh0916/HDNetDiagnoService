//
//  HDNetTimer.m
//  fffff
//
//  Created by m w on 2023/5/29.
//  Copyright © 2023 hundun. All rights reserved.
//

#import "HDNetTimer.h"
#include <sys/time.h>
@implementation HDNetTimer

+ (long)getMicroSeconds {
    struct timeval time;
    gettimeofday(&time,NULL);
    return time.tv_usec;
}

+ (long)computeDurationSince:(long)uTime {
    long now = [HDNetTimer getMicroSeconds];
    if (now < uTime) {
        return 1000000 - uTime + now;
    }
    return now - uTime;
}

@end
