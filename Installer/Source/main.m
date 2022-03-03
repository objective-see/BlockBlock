//
//  file: main.m
//  project: blockblock (config app)
//  description: main interface, for config
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;
@import Sentry;

#import "main.h"
#import "consts.h"
#import "logging.h"
#import "utilities.h"
#import "Configure.h"

/* To build:
 
 1. Comment out Installer's 'Run Script' (no need to copy in app/helper)
 2. Build Installer in 'Release Mode'
 3. Copy Installer to Application
 4. Comment in Installer's 'Run Script'
 5. Build Installer in 'Achive Mode'
 
 */

//main interface
int main(int argc, char *argv[])
{
    //status
    int status = -1;
    
    //init crash reporting
    [SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
        options.dsn = SENTRY_DSN;
        options.debug = YES;
    }];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"BlockBlock (in/unin)staller launched with %@", NSProcessInfo.processInfo.arguments]);
    
    //cmdline install?
    if(YES == [NSProcessInfo.processInfo.arguments containsObject:CMD_INSTALL])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"performing commandline install");
        
        //install
        if(YES != cmdlineInterface(ACTION_INSTALL_FLAG))
        {
            //err msg
            printf("\nBLOCKBLOCK ERROR: install failed\n\n");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        printf("BLOCKBLOCK: install ok!\n\n");
        
        //happy
        status = 0;
        
        //done
        goto bail;
    }
    
    //cmdline uninstall?
    else if(YES == [NSProcessInfo.processInfo.arguments containsObject:CMD_UNINSTALL])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"performing commandline uninstall");
        
        //install
        if(YES != cmdlineInterface(ACTION_UNINSTALL_FLAG))
        {
            //err msg
            printf("\nBLOCKBLOCK ERROR: uninstall failed\n\n");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        printf("BLOCKBLOCK: uninstall ok!\n\n");
        
        //happy
        status = 0;
        
        //done
        goto bail;
    }
    
    //default run mode
    // just kick off main app logic
    status = NSApplicationMain(argc, (const char **)argv);
    
bail:
    
    return status;
}

//cmdline interface
// install or uninstall
BOOL cmdlineInterface(int action)
{
    //flag
    BOOL wasConfigured = NO;
    
    //configure obj
    Configure* configure = nil;
    
    //ignore SIGPIPE
    signal(SIGPIPE, SIG_IGN);
    
    //alloc/init
    configure = [[Configure alloc] init];
    
    //first check root
    if(0 != geteuid())
    {
        //err msg
        printf("\nBLOCKBLOCK ERROR: cmdline interface actions require root!\n\n");
        
        //bail
        goto bail;
    }
    
    //configure
    wasConfigured = [configure configure:action];
    if(YES != wasConfigured)
    {
        //bail
        goto bail;
    }
    
    //happy
    wasConfigured = YES;
    
bail:
    
    //cleanup
    if(nil != configure)
    {
        //cleanup
        [configure removeHelper];
    }
    
    return wasConfigured;
}
