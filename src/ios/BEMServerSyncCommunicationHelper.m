//
//  DataUtils.m
//  CFC_Tracker
//
//  Created by Kalyanaraman Shankari on 3/9/15.
//  Copyright (c) 2015 Kalyanaraman Shankari. All rights reserved.
//

#import <Foundation/NSObjCRuntime.h>
#import <objc/objc.h>
#import <objc/runtime.h>
#import "LocalNotificationManager.h"

#import "SimpleLocation.h"
#import "TimeQuery.h"
#import "MotionActivity.h"
#import "LocationTrackingConfig.h"
#import "BEMServerSyncCommunicationHelper.h"

#import "BEMCommunicationHelper.h"
#import "BEMConnectionSettings.h"

#import "BEMActivitySync.h"
#import "BEMBuiltinUserCache.h"
#import "BEMConstants.h"
#import "Bolts/Bolts.h"
#import "DataUtils.h"
#import "StatsEvent.h"
#import "Battery.h"
#import "Timer.h"

static NSString* kUsercachePutPath = @"/usercache/put";
static NSString* kUsercacheGetPath = @"/usercache/get";
static NSString* kSetStatsPath = @"/stats/set";

@implementation BEMServerSyncCommunicationHelper

+ (BFTask*) backgroundSync {
    [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                               @"backgroundSync called"] showUI:TRUE];
    
    StatsEvent* se = [[StatsEvent alloc] initForEvent:@"sync_launched"];
    [[BuiltinUserCache database] putMessage:@"key.usercache.client_nav_event" value:se];

    NSMutableArray *tasks = [NSMutableArray array];
    [tasks addObject:[self pushAndClearUserCache]];
    [tasks addObject:[self pullIntoUserCache]];
    return [BFTask taskForCompletionOfAllTasks:tasks];
}

+ (BFTask*) pushAndClearUserCache {
    Timer* t = [[Timer new] init];
    /*
     * In iOS, we can only sign up for activity updates when the app is in the foreground
     * (from https://developer.apple.com/library/ios/documentation/CoreMotion/Reference/CMMotionActivityManager_class/index.html#//apple_ref/occ/instm/CMMotionActivityManager/startActivityUpdatesToQueue:withHandler:)
     * "The handler block is executed on a best effort basis and updates are not delivered while your app is suspended. If updates arrived while your app was suspended, the last update is delivered to your app when it resumes execution."
     * However, apple automatically stores the activities, and they can be retrieved in a batch.
     * https://developer.apple.com/library/ios/documentation/CoreMotion/Reference/CMMotionActivityManager_class/index.html#//apple_ref/occ/instm/CMMotionActivityManager/queryActivityStartingFromDate:toDate:toQueue:withHandler:
     * "A delay of up to several minutes in reported activities is expected."
     *
     * Since we now detect trip end only after the user has been stationary for a while, this should be fine.
     * We need to test this more carefully when we switch to the visit-based tracking.
     */
    [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                               @"pushAndClearUserCache called"] showUI:FALSE];
    NSArray* locEntriesToPush = [[BuiltinUserCache database] syncPhoneToServer];
    if ([locEntriesToPush count] == 0) {
        [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                   @"locEntriesToPush count == 0, returning "] showUI:FALSE];
        return [BFTask taskWithResult:@(TRUE)];
    }
    
    BFTaskCompletionSource *task = [BFTaskCompletionSource taskCompletionSource];
    [BEMActivitySync getCombinedArray:locEntriesToPush withHandler:^(NSArray *combinedArray) {
        TimeQuery* tq = [BuiltinUserCache getTimeQuery:locEntriesToPush];
        [self pushAndClearCombinedData:combinedArray timeQuery:tq task:task timer:t];
    }];
    return task.task;
}

+ (void) pushAndClearCombinedData:(NSArray*)entriesToPush timeQuery:(TimeQuery*)tq
                             task:(BFTaskCompletionSource*)task timer:(Timer*) t {
    if (entriesToPush.count == 0) {
        [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                   @"No data to send, returning early"] showUI:FALSE];
    } else {
        [self phone_to_server:entriesToPush
                             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                 // Only delete trips after they have been successfully pushed
                                 if (error == nil) {
                                 [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                                            @"successfully pushed %ld entries to the server",
                                                                            (unsigned long)entriesToPush.count]
                                                                    showUI:TRUE];
                                     [[BuiltinUserCache database] clearEntries:tq];
                                     // rw-docs are pushed like entries, so let's handle them here
                                     [[BuiltinUserCache database] clearSupersededRWDocs:tq];
                                     StatsEvent* se = [[StatsEvent alloc] initForReading:@"push_duration" withReading:[t elapsed_secs]];
                                     [[BuiltinUserCache database] putMessage:@"key.usercache.client_time" value:se];
                                 } else {
                                     [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                                                @"Got error %@ while pushing changes to server, retaining data", error] showUI:TRUE];
                                     StatsEvent* se = [[StatsEvent alloc] initForReading:@"push_duration" withReading:[t elapsed_secs]];
                                     [[BuiltinUserCache database] putMessage:@"key.usercache.client_time" value:se];
                                 }
                                 [task setResult:@(TRUE)];
                             }];
    }
}

+(void)phone_to_server:(NSArray *)entriesToPush completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSMutableDictionary *toPush = [[NSMutableDictionary alloc] init];
    [toPush setObject:entriesToPush forKey:@"phone_to_server"];
    
    NSURL* kBaseURL = [[ConnectionSettings sharedInstance] getConnectUrl];
    NSURL* kUsercachePutURL = [NSURL URLWithString:kUsercachePutPath
                                 relativeToURL:kBaseURL];
    
    CommunicationHelper *executor = [[CommunicationHelper alloc] initPost:kUsercachePutURL data:toPush completionHandler:completionHandler];
    [executor execute];
}

+(BFTask*) pullIntoUserCache {
    /*
     * Every time the app is launched, check the battery level. We are not signing up for battery level notifications because we don't want
     * to contribute to the battery drain ourselves. Instead, we are going to check the battery level when the app is launched anyway for other reasons,
     * by the user, or as part of background sync.
     */
    [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                               @"pullIntoUserCache called"] showUI:FALSE];
    BFTaskCompletionSource *task = [BFTaskCompletionSource taskCompletionSource];
    [DataUtils saveBatteryAndSimulateUser];
    
    [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                               @"about to launch remote call for server_to_phone"] showUI:FALSE];
    Timer* t = [[Timer new] init];
    
    // First, we delete all obsolete documents
    TimeQuery* tq = [TimeQuery new];
    tq.startTs = 0;
    tq.endTs = [DataUtils dateToTs:[NSDate date]];;
    [[BuiltinUserCache database] clearObsoleteDocs:tq];
    // Called in order to download data in the background
    [self server_to_phone:^(NSData *data, NSURLResponse *response, NSError *error) {
        [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                   @"received response for server_to_phone"] showUI:FALSE];

        if (error != NULL) {
            [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                       @"Got error %@ while retrieving data", error] showUI:TRUE];

            if ([error.domain isEqualToString:errorDomain] && (error.code == authFailedNeedUserInput)) {
                [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                           @"Please sign in"] showUI:TRUE];
            }
            [task setResult:@(FALSE)];
        } else {
            if (data == NULL) {
                [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                           @"Got data == NULL while retrieving data"] showUI:TRUE];

                StatsEvent* se = [[StatsEvent alloc] initForReading:@"sync_pull_list_size" withReading:0];
                [[BuiltinUserCache database] putMessage:@"key.usercache.client_time" value:se];
                [task setResult:@(TRUE)];
            } else {
                [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                           @"Got non NULL data while retrieving data"] showUI:FALSE];
                NSInteger newSectionCount = [self fetchedData:data];
                [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                           @"Retrieved %@ documents", @(newSectionCount)] showUI:TRUE];

                StatsEvent* se = [[StatsEvent alloc] initForReading:@"sync_pull_list_size" withReading:newSectionCount];
                [[BuiltinUserCache database] putMessage:@"key.usercache.client_time" value:se];

                if (newSectionCount > 0) {
                    // Note that we need to update the UI before calling the completion handler, otherwise
                    // when the view appears, users won't see the newly fetched data!
                    [[NSNotificationCenter defaultCenter] postNotificationName:BackgroundRefreshNewData
                                                                        object:self];
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"edu.berkeley.eecs.emission.sync.NEW_DATA"
                                                                        object:nil
                                                                      userInfo:nil];
                    [task setResult:@(TRUE)];
                } else {
                    [task setResult:@(TRUE)];
                }
            }
            StatsEvent* se = [[StatsEvent alloc] initForReading:@"pull_duration" withReading:[t elapsed_secs]];
            [[BuiltinUserCache database] putMessage:@"key.usercache.client_time" value:se];
        }
    }];
    return task.task;
}

// This is the callback that is invoked when the async data collection ends.
// We are going to parse the JSON in here for simplicity
+ (NSInteger)fetchedData:(NSData *)responseData {
    NSError *error;
    NSDictionary *documentDict = [NSJSONSerialization JSONObjectWithData:responseData
                                                                options:kNilOptions
                                                                  error: &error];
    NSArray *newDocs = [documentDict objectForKey:@"server_to_phone"];
    for (NSDictionary* currDoc in newDocs) {
        [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                   @"currDoc has keys %@", currDoc.allKeys] showUI:FALSE];
    }
    [[BuiltinUserCache database] syncServerToPhone:newDocs];
    
    // NSLog(@"documents: %@", newDocs);
    
    return [newDocs count];
}

+(void)server_to_phone:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSLog(@"CommunicationHelper.server_to_phone called!");
    NSMutableDictionary *blankDict = [[NSMutableDictionary alloc] init];
    NSURL* kBaseURL = [[ConnectionSettings sharedInstance] getConnectUrl];
    NSURL* kUsercacheGetURL = [NSURL URLWithString:kUsercacheGetPath
                                            relativeToURL:kBaseURL];
    CommunicationHelper *executor = [[CommunicationHelper alloc] initPost:kUsercacheGetURL data:blankDict completionHandler:completionHandler];
    [executor execute];
}

@end
