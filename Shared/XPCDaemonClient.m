//
//  file: XPCDaemonClient.m
//  project: BlockBlock (shared)
//  description: talk to daemon via XPC (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "XPCUser.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "XPCUserProto.h"
#import "XPCDaemonClient.h"

/* GLOBALS */

//alert (windows)
extern NSMutableDictionary* alerts;

@implementation XPCDaemonClient

@synthesize daemon;

//init
// create XPC connection & set remote obj interface
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //alloc/init
        daemon = [[NSXPCConnection alloc] initWithMachServiceName:DAEMON_MACH_SERVICE options:0];
        
        //set remote object interface
        self.daemon.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCDaemonProtocol)];
        
        //set exported object interface (protocol)
        self.daemon.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCUserProtocol)];
        
        //set exported object
        // this will allow daemon to invoke user methods!
        self.daemon.exportedObject = [[XPCUser alloc] init];
    
        //resume
        [self.daemon resume];
    }
    
    return self;
}

//get preferences
// note: synchronous, will block until daemon responds
-(NSDictionary*)getPreferences
{
    //preferences
    __block NSDictionary* preferences = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__]);
    
    //request preferences
    [[self.daemon synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute daemon XPC method '%s' (error: %@)", __PRETTY_FUNCTION__, proxyError]);
        
     }] getPreferences:^(NSDictionary* preferencesFromDaemon)
     {
         //dbg msg
         logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got preferences: %@", preferencesFromDaemon]);
         
         //save
         preferences = preferencesFromDaemon;
         
     }];
    
    return preferences;
}

//update (save) preferences
-(void)updatePreferences:(NSDictionary*)preferences
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__]);
    
    //update prefs
    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute daemon XPC method '%s' (error: %@)", __PRETTY_FUNCTION__, proxyError]);
          
    }] updatePreferences:preferences];
    
    return;
}

//get rules
// note: synchronous, will block until daemon responds
-(NSArray*)getRules
{
    //unarchived rules
    __block NSDictionary* unarchivedRules = nil;
    
    //rules
    __block NSMutableArray* rules = nil;
    
    //error
    __block NSError* error = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__]);
    
    //make XPC request to get rules
    [[self.daemon synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute daemon XPC method '%s' (error: %@)", __PRETTY_FUNCTION__, proxyError]);
        
    }] getRules:^(NSData* archivedRules)
    {
        //unarchive
        unarchivedRules = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithArray: @[[NSMutableDictionary class], [NSMutableArray class], [NSString class], [NSNumber class], [Rule class]]]
                                                    fromData:archivedRules error:&error];
        
        if(nil != error)
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to unarchive rules: %@", error]);
        }
        
        //init
        rules = [NSMutableArray array];
        
        //convert into array (for UI)
        for(NSString* key in unarchivedRules)
        {
            //add (each) processes rules
            [rules addObjectsFromArray:unarchivedRules[key][KEY_RULES]];
        }
        
    }];
    
    return rules;
}

//delete rule
-(NSArray*)deleteRule:(Rule*)rule
{
    //unarchived rules
    __block NSDictionary* unarchivedRules = nil;
    
    //rules
    __block NSMutableArray* rules = nil;
    
    //error
    __block NSError* error = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__]);
    
    //delete rule
    [[self.daemon synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute daemon XPC method '%s' (error: %@)", __PRETTY_FUNCTION__, proxyError]);
        
    }] deleteRule:rule reply:^(NSData* archivedRules)
    {
        //unarchive
        unarchivedRules = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithArray: @[[NSMutableDictionary class], [NSMutableArray class], [NSString class], [NSNumber class], [Rule class]]]
                                                    fromData:archivedRules error:&error];
        if(nil != error)
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to unarchive rules: %@", error]);
        }
        
        //init
        rules = [NSMutableArray array];
        
        //convert into array (for UI)
        for(NSString* key in unarchivedRules)
        {
            //add (each) processes rules
            [rules addObjectsFromArray:unarchivedRules[key][KEY_RULES]];
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"received updated rules %@", rules]);
        
    }];
    
    return rules;
}

//send alert response back to the deamon
-(void)alertReply:(NSDictionary*)alert
{
    //pool
    @autoreleasepool {
        
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__]);
    
    //respond to alert
    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute daemon XPC method '%s' (error: %@)", __PRETTY_FUNCTION__, proxyError]);
        
    }] alertReply:alert];
    
    //sync to remove alert (window)
    @synchronized(alerts)
    {
        //remove
        alerts[alert[ALERT_UUID]] = nil;
    }
    
    //set app's background/foreground state
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]) setActivationPolicy];
        
    } //pool

    return;
}

@end
