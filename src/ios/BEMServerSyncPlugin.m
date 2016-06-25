#import "BEMServerSyncPlugin.h"
#import "BEMServerSyncCommunicationHelper.h"
#import "BEMServerSyncConfig.h"
#import "BEMServerSyncConfigManager.h"
#import "LocalNotificationManager.h"
#import <Parse/Parse.h>
#import "DataUtils.h"

@implementation BEMServerSyncPlugin

- (void)pluginInitialize
{
    if ([BEMServerSyncConfigManager instance].ios_use_remote_push) {
        if ([UIApplication instancesRespondToSelector:@selector(registerForRemoteNotifications)]) {
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        } else if ([UIApplication instancesRespondToSelector:@selector(registerForRemoteNotificationTypes:)]){
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeAlert)];
        } else {
            NSLog(@"registering for remote notifications not supported");
        }
    } else {
    }
}


- (void)forceSync:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = [command callbackId];
    @try {
        [[BEMServerSyncCommunicationHelper backgroundSync] continueWithBlock:^id(BFTask *task) {
            [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                       @"all sync completed"] showUI:TRUE];
            CDVPluginResult* result = [CDVPluginResult
                                       resultWithStatus:CDVCommandStatus_OK];
            [self.commandDelegate sendPluginResult:result callbackId:callbackId];
            return nil;
        }];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While initializing, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}

- (void)getConfig:(CDVInvokedUrlCommand *)command
{
    NSString* callbackId = [command callbackId];
    
    @try {
        BEMServerSyncConfig* cfg = [BEMServerSyncConfigManager instance];
        NSDictionary* retDict = [DataUtils wrapperToDict:cfg];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK
                                   messageAsDictionary:retDict];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While getting settings, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}


- (void)setConfig:(CDVInvokedUrlCommand *)command
{
    NSString* callbackId = [command callbackId];
    @try {
        NSDictionary* newDict = [[command arguments] objectAtIndex:0];
        BEMServerSyncConfig* newCfg = [BEMServerSyncConfig new];
        [DataUtils dictToWrapper:newDict wrapper:newCfg];
        [BEMServerSyncPlugin applySync];
        [BEMServerSyncConfigManager updateConfig:newCfg];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While updating settings, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    
}

+ (void)applySync
{
    if ([BEMServerSyncConfigManager instance].ios_use_remote_push) {
        NSString* channel = [NSString stringWithFormat:@"%@_interval", @([BEMServerSyncConfigManager instance].sync_interval)];
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        [currentInstallation removeObjectForKey:@"channels"];
        [currentInstallation addUniqueObject:channel forKey:@"channels"];
    } else {
        [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:[BEMServerSyncConfigManager instance].sync_interval];
    }
}

@end

