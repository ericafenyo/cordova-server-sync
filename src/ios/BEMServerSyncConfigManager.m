//
//  ServerSyncConfigManager.m
//  emission
//
//  Created by Kalyanaraman Shankari on 6/21/16.
//
//

#import "BEMServerSyncConfigManager.h"
#import "BEMBuiltinUserCache.h"

#define SENSOR_CONFIG_KEY @"key.usercache.sync_config"

static BEMServerSyncConfig *_instance;

@implementation BEMServerSyncConfigManager

+ (BEMServerSyncConfig*) instance {
    if (_instance == NULL) {
        _instance = [self readFromCache];
        if (_instance == NULL) {
            // This is still NULL, which means that there is no document in the usercache.
            // Let us add a dummy one based on the default settings
            // we don't want to save it to the database because then it will look like a user override
            _instance = [BEMServerSyncConfig new];
        }
    }
    return _instance;
}

+ (BEMServerSyncConfig*) readFromCache {
    return (BEMServerSyncConfig*)[[BuiltinUserCache database] getDocument:SENSOR_CONFIG_KEY wrapperClass:[BEMServerSyncConfig class]];
}

+ (void) updateConfig:(BEMServerSyncConfig*) newConfig {
    [[BuiltinUserCache database] putReadWriteDocument:SENSOR_CONFIG_KEY value:newConfig];
    _instance = newConfig;
}

@end
