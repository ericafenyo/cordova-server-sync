#import "BEMServerSyncPlugin.h"
#import "BEMServerSyncCommunicationHelper.h"
#import "BEMServerSyncConfig.h"
#import "BEMServerSyncConfigManager.h"
#import "LocalNotificationManager.h"
#import <Parse/Parse.h>
#import "DataUtils.h"
#import "BEMBuiltinUserCache.h"

@implementation BEMServerSyncPlugin

- (void)pluginInitialize
{
}


- (void)forceSync:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = [command callbackId];
    @try {
        [[BEMServerSyncCommunicationHelper backgroundSync] continueWithBlock:^id(BFTask *task) {
            [[BuiltinUserCache database] checkAfterPull];
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
        [BEMServerSyncConfigManager updateConfig:newCfg];
        [BEMServerSyncPlugin restartSync];
        
        PFInstallation* currentInstallation = [PFInstallation currentInstallation];
        [currentInstallation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            if (succeeded) {
                [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                           @"Successfully changed channel to %ld for installation", newCfg.sync_interval]];
            } else {
                [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                           @"Error %@ while changing channel to %ldfor installation", error.description, newCfg.sync_interval] showUI:TRUE];
                @throw error;
            }
        }];
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

+ (void) restartSync
{
    if ([BEMServerSyncConfigManager instance].isManual)
    {
        [LocalNotificationManager addNotification:[NSString stringWithFormat: @"Start manual sync"]];
        [self startManualSync];
    } else {
        [LocalNotificationManager addNotification:[NSString stringWithFormat: @"Start auto sync"]];
        [self applyAutoSync];
    }
}
    
+ (void) startManualSync
{
    if ([BEMServerSyncConfigManager instance].ios_use_remote_push) {
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        [currentInstallation removeObjectForKey:@"channels"];
        [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                   @"For remotePush, remove channel"] showUI:TRUE];
    } else {
        [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval: DBL_MAX];
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        [currentInstallation removeObjectForKey:@"channels"];
    }
}

+ (void)applyAutoSync
{
    if ([BEMServerSyncConfigManager instance].ios_use_remote_push) {
        NSString* channel = [NSString stringWithFormat:@"interval_%@", @([BEMServerSyncConfigManager instance].sync_interval)];
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        [currentInstallation removeObjectForKey:@"channels"];
        [currentInstallation addUniqueObject:channel forKey:@"channels"];
        [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                   @"For remotePush, setting channel = %@", channel] showUI:TRUE];
    } else {
        [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:[BEMServerSyncConfigManager instance].sync_interval];
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        [currentInstallation removeObjectForKey:@"channels"];
    }
}

@end
