//
//  file: Configure.m
//  project: BlockBlock (config)
//  description: install/uninstall logic
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "Configure.h"
#import "utilities.h"

#import <IOKit/IOKitLib.h>
#import <Foundation/Foundation.h>
#import <Security/Authorization.h>
#import <ServiceManagement/ServiceManagement.h>

@implementation Configure

@synthesize gotHelp;
@synthesize xpcComms;

//invokes appropriate action
// either install || uninstall logic
-(BOOL)configure:(NSInteger)parameter
{
    //return var
    BOOL wasConfigured = NO;
    
    //uninstall flag
    BOOL uninstallFlag = UNINSTALL_FULL;
    
    //before we install helper
    // kill client, otherwise it will alert
    execTask(KILL_ALL, @[[APP_NAME stringByDeletingPathExtension]], YES, NO);
    
    //get help
    if(YES != [self initHelper])
    {
        //err msg
        logMsg(LOG_ERR, @"ERROR: failed to init helper tool");
        
        //bail
        goto bail;
    }
    
    //install
    if(ACTION_INSTALL_FLAG == parameter)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"installing...");
        
        //already installed?
        // perform an uninstall
        if(YES == [self isInstalled])
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"already installed, so uninstalling...");
            
            //existing install, a beta?
            // set flag to perform full uninstall
            if(YES == [self isBetaInstalled])
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"previous version is a beta, so will fully uninstall");
                
                //set flag
                uninstallFlag = UNINSTALL_FULL;
            }
            //non-beta
            // set flag to perform partial uninstall
            else
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"previous version is not beta, so only partially uninstall");
                
                //set flag
                uninstallFlag = UNINSTALL_PARTIAL;
            }
            
            //uninstall
            if(YES != [self uninstall:uninstallFlag])
            {
                //bail
                goto bail;
            }
            
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"uninstalled (type: %@)", (uninstallFlag == UNINSTALL_PARTIAL) ? @"partial" : @"full"]);
        }
        
        //install
        if(YES != [self install])
        {
            //bail
            goto bail;
        }
        
        //load launch daemon
        [self toggleDaemon:YES];
        
        //give daemon a few seconds to start
        // as it checks for FDA, etc etc
        [NSThread sleepForTimeInterval:2.00f];
        
        //dbg msg
        logMsg(LOG_DEBUG, @"installed!");
    }	
    //uninstall
    else if(ACTION_UNINSTALL_FLAG == parameter)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"uninstalling...");
        
        //uninstall
        if(YES != [self uninstall:UNINSTALL_FULL])
        {
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"uninstalled!");
    }

    //no errors
    wasConfigured = YES;
    
bail:
    
    return wasConfigured;
}

//determine if installed
// check if various firewall components are present
-(BOOL)isInstalled
{
    //flag
    BOOL installed = NO;
    
    //daemon path
    NSString* launchDaemon = nil;
    
    //launch daemon plist
    NSString* launchDaemonPlist = nil;
    
    //launch daemon plist (beta)
    NSString* launchDaemonBetaPlist = nil;
    
    //init path to daemon
    launchDaemon = [INSTALL_DIRECTORY stringByAppendingPathComponent:LAUNCH_DAEMON];
    
    //init path to launch daemon plist
    launchDaemonPlist = [@"/Library/LaunchDaemons" stringByAppendingPathComponent:LAUNCH_DAEMON_PLIST];
    
    //init path to launch daemon (beta) plist
    launchDaemonBetaPlist = [@"/Library/LaunchDaemons" stringByAppendingPathComponent:LAUNCH_DAEMON_BETA_PLIST];
    
    //check for installed components
    installed = ( (YES == [[NSFileManager defaultManager] fileExistsAtPath:launchDaemon]) ||
                  (YES == [[NSFileManager defaultManager] fileExistsAtPath:launchDaemonPlist]) ||
                  (YES == [[NSFileManager defaultManager] fileExistsAtPath:launchDaemonBetaPlist]));
    
    return installed;
}

//determine if installed version is a beta
-(BOOL)isBetaInstalled
{
    //launch daemon plist (beta)
    NSString* launchDaemonBetaPlist = nil;
    
    //init path to launch daemon (beta) plist
    launchDaemonBetaPlist = [@"/Library/LaunchDaemons" stringByAppendingPathComponent:LAUNCH_DAEMON_BETA_PLIST];
    
    //check for installed components
    return (YES == [[NSFileManager defaultManager] fileExistsAtPath:launchDaemonBetaPlist]);
}

//check for FDA
// has daemon has set FDA flag?
-(BOOL)shouldRequestFDA
{
    //flag
    BOOL shouldRequest = YES;
    
    //preferences
    NSDictionary* preferences = nil;
    
    //load prefs and check
    preferences = [NSDictionary dictionaryWithContentsOfFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE]];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"checking preferences for 'got FDA' flag: %@", preferences]);
    
    //check for flag
    if(YES == [preferences[PREF_GOT_FDA] boolValue])
    {
        //no need
        shouldRequest = NO;
    }

    return shouldRequest;
}

//init helper tool
// install and establish XPC connection
-(BOOL)initHelper
{
    //bail if we're already G2G
    if(YES == self.gotHelp)
    {
        //all set
        goto bail;
    }
    
    //install
    if(YES != [self blessHelper])
    {
        //err msg
        syslog(LOG_ERR, "ERROR: failed to install helper tool");
        
        //bail
        goto bail;
    }
    
    //init XPC comms
    xpcComms = [[HelperComms alloc] init];
    if(nil == xpcComms)
    {
        //err msg
        syslog(LOG_ERR, "ERROR: failed to connect to helper tool");
        
        //bail
        goto bail;
    }
    
    //happy
    self.gotHelp = YES;
    
bail:
    
    return self.gotHelp;
}

//install helper tool
// sets 'wasBlessed' iVar
-(BOOL)blessHelper
{
    //flag
    BOOL wasBlessed = NO;
    
    //auth ref
    AuthorizationRef authRef = NULL;
    
    //error
    CFErrorRef error = NULL;
    
    //auth item
    AuthorizationItem authItem = {};
    
    //auth rights
    AuthorizationRights authRights = {};
    
    //auth flags
    AuthorizationFlags authFlags = 0;
    
    //create auth
    if(errAuthorizationSuccess != AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authRef))
    {
        //err msg
        syslog(LOG_ERR, "ERROR: failed to create authorization");
        
        //bail
        goto bail;
    }
    
    //init auth item
    memset(&authItem, 0x0, sizeof(authItem));
    
    //set name
    authItem.name = kSMRightBlessPrivilegedHelper;
    
    //set auth count
    authRights.count = 1;
    
    //set auth items
    authRights.items = &authItem;
    
    //init flags
    authFlags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    
    //get auth rights
    if(errAuthorizationSuccess != AuthorizationCopyRights(authRef, &authRights, kAuthorizationEmptyEnvironment, authFlags, NULL))
    {
        //err msg
        syslog(LOG_ERR, "ERROR: failed to copy authorization rights");
        
        //bail
        goto bail;
    }
    
    //bless
    if(YES != (BOOL)SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)(CONFIG_HELPER_ID), authRef, &error))
    {
        //err msg
        syslog(LOG_ERR, "ERROR: failed to bless job (%s)", ((__bridge NSError*)error).description.UTF8String);
        
        //bail
        goto bail;
    }
    
    //happy
    wasBlessed = YES;
    
bail:
    
    //free auth ref
    if(NULL != authRef)
    {
        //free
        AuthorizationFree(authRef, kAuthorizationFlagDefaults);
        
        //unset
        authRef = NULL;
    }
    
    //free error
    if(NULL != error)
    {
        //release
        CFRelease(error);
        
        //unset
        error = NULL;
    }
    
    return wasBlessed;
}

//remove helper (daemon)
-(BOOL)removeHelper
{
    //return/status var
    __block BOOL wasRemoved = NO;
    
    //if needed
    // tell helper to remove itself
    if(YES == self.gotHelp)
    {
        //cleanup
        wasRemoved = [self.xpcComms cleanup];
        
        //unset var
        if(YES == wasRemoved)
        {
            //unset
            self.gotHelp = NO;
        }
    }
    //didn't need to remove
    // just set ret var to 'ok'
    else
    {
        //set
        wasRemoved = YES;
    }
    
    return wasRemoved;
}

//install
-(BOOL)install
{
    //return/status var
    __block BOOL wasInstalled = NO;
    
    //path to login item
    NSString* loginItem = nil;
    
    //install
    // note, this is async
    wasInstalled = [xpcComms install];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"privileged helper item install logic completed (%d)", wasInstalled]);
    
    //sanity check
    // make sure xpc install logic succeeded
    if(YES != wasInstalled)
    {
        //bail
        goto bail;
    }
    
    //register daemon
    if(YES != [self lsRegisterDaemon:YES])
    {
        //err msg
        // ...though not fatal
        logMsg(LOG_ERR, @"failed to register daemon");
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"registered daemon");
    
    //init path to login item
    loginItem = [@"/Applications" stringByAppendingPathComponent:APP_NAME];
    
    //install login item
    // can't do this in script since it needs to be executed as logged in user (not r00t)
    if(YES != toggleLoginItem([NSURL fileURLWithPath:loginItem], ACTION_INSTALL_FLAG))
    {
        //err msg
        logMsg(LOG_ERR, @"failed to install login item");
        
        //set error
        wasInstalled = NO;
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"installed login item (%@)", loginItem]);
    
    //(still) happy
    wasInstalled = YES;
    
bail:
    
    return wasInstalled;
}

//un/register daemon with launch services
-(BOOL)lsRegisterDaemon:(BOOL)shouldRegister
{
    //flag
    BOOL result = NO;
    
    //task results
    NSDictionary* results = nil;
    
    //args
    NSArray* arguments = nil;
    
    //register?
    if(YES == shouldRegister)
    {
        //args for register
        arguments = @[[INSTALL_DIRECTORY stringByAppendingPathComponent:LAUNCH_DAEMON]];
    }
    //unregister
    else
    {
        //args for unregister
        arguments = @[@"-u", [INSTALL_DIRECTORY stringByAppendingPathComponent:LAUNCH_DAEMON]];
    }
    
    //exec lsregister
    results = execTask(LSREGISTER, arguments, YES, NO);
    if( (nil == results[EXIT_CODE]) ||
        (noErr != [results[EXIT_CODE] intValue]) )
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'LSREGISTER' (%@)", results]);
        
        //bail
        goto bail;
    }
    
    //happy
    result = YES;
    
bail:
    
    return result;
}

//load/unload lauch daemon
// calls into helper via XPC
-(BOOL)toggleDaemon:(BOOL)shouldLoad
{
    //return/status var
    __block BOOL wasLoaded = NO;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking XPC message to toggle (%d) launch daemon", shouldLoad]);
    
    //toggle
    wasLoaded = [xpcComms toggleDaemon:shouldLoad];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"privileged helper item 'toggleDaemon' logic completed (%d)", wasLoaded]);
        
    return wasLoaded;
}

//uninstall
-(BOOL)uninstall:(BOOL)full
{
    //return/status var
    __block BOOL wasUninstalled = NO;
    
    //path to login item
    NSString* loginItem = nil;

    //init path to login item
    loginItem = [@"/Applications" stringByAppendingPathComponent:APP_NAME];
    
    //uninstall login item, first
    // can't do this in script since it needs to be executed as logged in user (not r00t)
    if(YES != toggleLoginItem([NSURL fileURLWithPath:loginItem], ACTION_UNINSTALL_FLAG))
    {
        //err msg
        // ...though not fatal
        logMsg(LOG_ERR, @"failed to uninstall login item");
    }
    
    #ifdef DEBUG
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"uninstalled login item (%@)", loginItem]);
    }
    #endif
    
    //unregister daemon
    if(YES != [self lsRegisterDaemon:NO])
    {
        //err msg
        // ...though not fatal
        logMsg(LOG_ERR, @"failed to unregister daemon");
    }
    
    #ifdef DEBUG
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"unregistered daemon");
    }
    #endif

    //uninstall
    wasUninstalled = [xpcComms uninstall:full];
    
    return wasUninstalled;
}

@end
