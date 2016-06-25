//
//  SyncConfig.m
//  emission
//
//  Created by Kalyanaraman Shankari on 6/21/16.
//
//

#import "BEMServerSyncConfig.h"

// 3600 secs = 1 hour
#define ONE_HOUR 60 * 60

@implementation BEMServerSyncConfig

-(id)init {
    self.sync_interval = ONE_HOUR;
    self.ios_use_remote_push = YES;
    return self;
}

@end
