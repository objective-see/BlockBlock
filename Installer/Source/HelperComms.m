//
//  file: HelperComms.h
//  project: BlockBlock (config)
//  description: interface to talk to blessed installer (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import OSLog;
@import Foundation;

#import "consts.h"
#import "AppDelegate.h"
#import "HelperComms.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation HelperComms

@synthesize daemon;
@synthesize xpcServiceConnection;

//init
// create XPC connection & set remote obj interface
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //alloc/init
        xpcServiceConnection = [[NSXPCConnection alloc] initWithMachServiceName:CONFIG_HELPER_ID options:0];
        
        //set remote object interface
        self.xpcServiceConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCProtocol)];
        
        //resume
        [self.xpcServiceConnection resume];
    }
    
    return self;
}

//install
-(BOOL)install
{
    //result
    __block BOOL result = NO;
    
    //dbg msg
    os_log_debug(logHandle, "invoking 'install' XPC method");
    
    //install
    [[self.xpcServiceConnection synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "failed to execute 'install' method on helper tool (error: %{public}@)", proxyError);
        
    }] install:[[NSBundle mainBundle] bundlePath] reply:^(NSNumber* xpcResult)
    {
        //capture result
        result = [xpcResult boolValue];
    }];
    
    return result;
}

//toggle launch daemon
-(BOOL)toggleDaemon:(BOOL)shouldLoad
{
    //result
    __block BOOL result = NO;
    
    //dbg msg
    os_log_debug(logHandle, "invoking 'toggleDaemon' XPC method");
    
    //install
    [[self.xpcServiceConnection synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "failed to execute 'toggleDaemon' method on helper tool (error: %{public}@)", proxyError);
        
    }] toggleDaemon:shouldLoad reply:^(NSNumber* xpcResult)
    {
        //capture results
        result = [xpcResult boolValue];
    }];
    
    return result;
}

//uninstall
-(BOOL)uninstall:(BOOL)full
{
    //result
    __block BOOL result = NO;
    
    //dbg msg
    os_log_debug(logHandle, "invoking 'uninstall' XPC method");
    
    //uninstall
    [[self.xpcServiceConnection synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "failed to execute 'uninstall' method on helper tool (error: %{public}@)", proxyError);
        
    }] uninstall:[[NSBundle mainBundle] bundlePath] full:full reply:^(NSNumber* xpcResult)
    {
         //capture results
         result = [xpcResult boolValue];
    }];
    
    return result;
}

//cleanup
-(BOOL)cleanup
{
    //result
    __block BOOL result = NO;
    
    //dbg msg
    os_log_debug(logHandle, "invoking 'cleanup' XPC method");
    
    //remove
    [[(NSXPCConnection*)self.xpcServiceConnection synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "failed to execute 'remove' method on helper tool (error: %{public}@)", proxyError);
          
    }] cleanup:^(NSNumber* xpcResult)
    {
        //capture results
        result = [xpcResult boolValue];
    }];
    
    return result;
}

@end
