//
//  file: main.m
//  project: BlockBlock (login item)
//  description: main; 'nuff said
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;

#import "consts.h"
#import "logging.h"
#import "utilities.h"

#import <sys/stat.h>

//check for daemon
BOOL isDaemonRunning(void);

//main interface
// sanity checks, then kick off app
int main(int argc, const char * argv[])
{
    //status
    int status = 0;
    
    //'no daemon' alert
    NSAlert* alert = nil;
    
    //dbg msg(s)
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"started: %@", [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleNameKey]]);
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"arguments: %@", [[NSProcessInfo processInfo] arguments]]);
    
    //init crash reporting
    // kicks off sentry.io
    initCrashReporting();
        
    //sanity check
    // make sure daemon is running
    // might have exited if doesn't have FDA!
    if(YES != isDaemonRunning())
    {
        //init alert
        alert = [[NSAlert alloc] init];
        
        //set style
        alert.alertStyle = NSAlertStyleInformational;
        
        //set main text
        alert.messageText = @"BlockBlock's launch daemon not active!";
        
        //set detailed text
        alert.informativeText = @"Please ensure the daemon was granted full disk access (fda). 🔓";
        
        //add button
        [alert addButtonWithTitle:@"Ok"];
        
        //show modal
        [alert runModal];
        
        //bail
        goto bail;
    }
    
    //launch app normally
    status = NSApplicationMain(argc, argv);
    
bail:
    
    return status;
}

//check for daemon
BOOL isDaemonRunning()
{
    //flag
    BOOL isRunning = NO;
    
    //path to (launch) daemon
    NSString* daemon = nil;
       
    //init path to (launch) daemon
    daemon = [NSString pathWithComponents:@[INSTALL_DIRECTORY, LAUNCH_DAEMON, @"Contents", @"MacOS", PRODUCT_NAME]];

    //check if daemon is running
    if(0 != [getProcessIDs(daemon, -1) count])
    {
        //happy!
        isRunning = YES;
    }
    
    return isRunning;
}
