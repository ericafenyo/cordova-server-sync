#import "BEMServerSyncPlugin.h"
#import "BEMServerSyncCommunicationHelper.h"
#import "BEMServerSyncConfig.h"
#import "BEMServerSyncConfigManager.h"
#import "LocalNotificationManager.h"
#import <Parse/Parse.h>
#import "DataUtils.h"

@implementation BEMServerSyncPlugin

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
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        // set the device token so that we know which device to change the token for
        newCfg.device_token = currentInstallation.deviceToken;
        [BEMServerSyncConfigManager updateConfig:newCfg];
        // iOS sync happens through silent push notifications, so the server needs
        // to be modified, not the client
        // Let's set the background fetch interval though so that we can report how
        // frequently it happens (whether we use it or not)
        [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:[BEMServerSyncConfigManager instance].sync_interval];
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

@end

