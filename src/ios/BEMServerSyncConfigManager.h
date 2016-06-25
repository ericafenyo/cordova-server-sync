//
//  ServerSyncConfigManager.h
//  emission
//
//  Created by Kalyanaraman Shankari on 6/21/16.
//
//

#import <Foundation/Foundation.h>
#import "BEMServerSyncConfig.h"

@interface BEMServerSyncConfigManager : NSObject

+ (BEMServerSyncConfig*) instance;
+ (void) updateConfig:(BEMServerSyncConfig*) newConfig;

@end
