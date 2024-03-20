//
//  file: XPCUserClient.m
//  project: BlockBlock (launch daemon)
//  description: talk to the user, via XPC
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import OSLog;

#import "Rules.h"
#import "Event.h"
#import "Events.h"
#import "consts.h"
#import "XPCListener.h"
#import "XPCUserClient.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//xpc connection
extern XPCListener* xpcListener;

@implementation XPCUserClient

//deliver alert to user
// note: this is synchronous so that errors can be detected
-(BOOL)deliverEvent:(Event*)event
{
    //flag
    __block BOOL xpcError = NO;
    
    //dbg msg
    os_log_debug(logHandle, "invoking user XPC method: 'alertShow'");
    
    //sanity check
    // no client connection?
    if(nil == xpcListener.client)
    {
        //dbg msg
        os_log_debug(logHandle, "no client is connected, alert will not be delivered");
        
        //set error
        xpcError = YES;
        
        //bail
        goto bail;
    }

    //send to user (client) to display
    [[xpcListener.client remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //set error
        xpcError = YES;
        
        //err msg
        os_log_error(logHandle, "ERROR: failed to invoke USER XPC method: 'alertShow' (error: %{public}@)", proxyError);

    }] alertShow:[event toAlert]];
    
bail:

    return !xpcError;
}

//request the removal of a login item
// these are context sensitive, so gotta be done in user's session
-(void)removeLoginItem:(NSURL*)loginItem reply:(void (^)(NSNumber*))reply;
{
    //dbg msg
    os_log_debug(logHandle, "invoking user XPC method: 'removeLoginItem'");
    
    //sanity check
    // no client connection?
    if(nil == xpcListener.client) reply([NSNumber numberWithInt:-1]);
    
    //send to user (client)
    [[xpcListener.client synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to invoke USER XPC method: 'removeLoginItem' (error: %{public}@)", proxyError);
        
        reply([NSNumber numberWithInt:-1]);

    }] removeLoginItem:loginItem reply:^(NSNumber* result)
    {
        //dbg msg
        os_log_debug(logHandle, "user XPC method responded with: %{public}@", result);
        
        //invoke block
        reply(result);
        
    }];
    
    return;
}

@end
