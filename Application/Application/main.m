//
//  file: main.m
//  project: BlockBlock (login item)
//  description: main; 'nuff said
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;
@import Sentry;

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
    
    //dbg msg(s)
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"started: %@", [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleNameKey]]);
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"arguments: %@", [[NSProcessInfo processInfo] arguments]]);
    
    //init crash reporting
    [SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
        options.dsn = SENTRY_DSN;
        options.debug = YES;
    }];
    
    //launch app normally
    status = NSApplicationMain(argc, argv);
    
bail:
    
    return status;
}
