#import <Cordova/CDV.h>

@interface BEMServerSyncPlugin: CDVPlugin <UINavigationControllerDelegate>

- (void) forceSync:(CDVInvokedUrlCommand*)command;
- (void) setConfig:(CDVInvokedUrlCommand*)command;

@end
