//
//  file: XPCListener.m
//  project: BlockBlock (launch daemon)
//  description: XPC listener for connections for user components
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"

#import "Rule.h"
#import "Rules.h"
#import "utilities.h"
#import "XPCDaemon.h"
#import "XPCListener.h"
#import "XPCUserProto.h"
#import "XPCDaemonProto.h"


#import <bsm/libbsm.h>

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

//interface for 'extension' to NSXPCConnection
// allows us to access the 'private' auditToken iVar
@interface ExtendedNSXPCConnection : NSXPCConnection
{
    //private iVar
    audit_token_t auditToken;
}
//private iVar
@property audit_token_t auditToken;

@end

//implementation for 'extension' to NSXPCConnection
// ->allows us to access the 'private' auditToken iVar
@implementation ExtendedNSXPCConnection

//private iVar
@synthesize auditToken;

@end

OSStatus SecTaskValidateForRequirement(SecTaskRef task, CFStringRef requirement);

//global rules obj
extern Rules* rules;

@implementation XPCListener

@synthesize client;
@synthesize listener;

//init
// create XPC listener
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //setup XPC listener
        if(YES != [self initListener])
        {
            //unset
            self =  nil;
            
            //bail
            goto bail;
        }
    }
    
bail:
    
    return self;
}

//setup XPC listener
-(BOOL)initListener
{
    //result
    BOOL result = NO;
    
    //init listener
    listener = [[NSXPCListener alloc] initWithMachServiceName:DAEMON_MACH_SERVICE];
    if(nil == self.listener)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to create mach service %@", DAEMON_MACH_SERVICE]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"created mach service %@", DAEMON_MACH_SERVICE]);
    
    //set delegate
    self.listener.delegate = self;
    
    //ready to accept connections
    [self.listener resume];
    
    //happy
    result = YES;
    
bail:
    
    return result;
}


#pragma mark -
#pragma mark NSXPCConnection method overrides

//automatically invoked
// allows NSXPCListener to configure/accept/resume a new incoming NSXPCConnection
// shoutout to writeup: https://blog.obdev.at/what-we-have-learned-from-a-vulnerability
-(BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    //flag
    BOOL shouldAccept = NO;
    
    //status
    OSStatus status = !errSecSuccess;
    
    //audit token
    audit_token_t auditToken = {0};
    
    //task ref
    SecTaskRef taskRef = 0;
    
    //code ref
    SecCodeRef codeRef = NULL;
    
    //code signing info
    CFDictionaryRef csInfo = NULL;
    
    //cs flags
    uint32_t csFlags = 0;
    
    //signing req string (main app)
    NSString* requirement = nil;

    //extract audit token
    auditToken = ((ExtendedNSXPCConnection*)newConnection).auditToken;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"received request to connect to XPC interface from: (%d)%@", audit_token_to_pid(auditToken), getProcessPath(audit_token_to_pid(auditToken))]);
    
    //obtain dynamic code ref
    status = SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef _Nullable)(@{(__bridge NSString *)kSecGuestAttributeAudit : [NSData dataWithBytes:&auditToken length:sizeof(audit_token_t)]}), kSecCSDefaultFlags, &codeRef);
    if(errSecSuccess != status)
    {
        //bail
        goto bail;
    }
    
    //validate code
    status = SecCodeCheckValidity(codeRef, kSecCSDefaultFlags, NULL);
    if(errSecSuccess != status)
    {
        //bail
        goto bail;
    }
    
    //get code signing info
    status = SecCodeCopySigningInformation(codeRef, kSecCSDynamicInformation, &csInfo);
    if(errSecSuccess != status)
    {
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"client's code signing info: %@", csInfo]);
    
    //extract flags
    csFlags = [((__bridge NSDictionary *)csInfo)[(__bridge NSString *)kSecCodeInfoStatus] unsignedIntValue];
    
    //gotta have hardened runtime
    if( !(CS_VALID & csFlags) &&
        !(CS_RUNTIME & csFlags) )
    {
        //bail
        goto bail;
    }
    
    //init signing req string
    requirement = [NSString stringWithFormat:@"anchor apple generic and identifier \"%@\" and certificate leaf [subject.CN] = \"%@\" and info [CFBundleShortVersionString] >= \"1.0.0\"", HELPER_ID, SIGNING_AUTH];
    
    //step 1: create task ref
    // uses NSXPCConnection's (private) 'auditToken' iVar
    taskRef = SecTaskCreateWithAuditToken(NULL, ((ExtendedNSXPCConnection*)newConnection).auditToken);
    if(NULL == taskRef)
    {
        //bail
        goto bail;
    }
    
    //step 2: validate
    // check that client is signed with Objective-See's and it's BlockBlock
    if(errSecSuccess != (status = SecTaskValidateForRequirement(taskRef, (__bridge CFStringRef)(requirement))))
    {
        //bail
        goto bail;
    }
    
    //set the interface that the exported object implements
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCDaemonProtocol)];
    
    //set object exported by connection
    newConnection.exportedObject = [[XPCDaemon alloc] init];
    
    //set type of remote object
    // user (login item/main app) will set this object
    newConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol: @protocol(XPCUserProtocol)];
    
    //save
    self.client = newConnection;
    
    //in background
    // notify that a new client connected
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
       //notify
       [[NSNotificationCenter defaultCenter] postNotificationName:USER_NOTIFICATION object:nil userInfo:nil];
    });
    
    //resume
    [newConnection resume];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"allowing XPC connection from client (pid: %d)", audit_token_to_pid(auditToken)]);
    
    //happy
    shouldAccept = YES;
    
bail:
    
    //release task ref object
    if(NULL != taskRef)
    {
        //release
        CFRelease(taskRef);
        taskRef = NULL;
    }
    
    //free cs info
    if(NULL != csInfo)
    {
        //free
        CFRelease(csInfo);
        csInfo = NULL;
    }
    
    //free code ref
    if(NULL != codeRef)
    {
        //free
        CFRelease(codeRef);
        codeRef = NULL;
    }
    
    return shouldAccept;
}

@end
