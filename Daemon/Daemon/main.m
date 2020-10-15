//
//  file: main.m
//  project: BlockBlock (launch daemon)
//  description: main interface/entry point for launch daemon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "main.h"
#import "Monitor.h"

@import Sentry;

/* GLOBALS */

//(file)monitor
Monitor* monitor = nil;

//main
// init & kickoff stuffz
int main(int argc, const char * argv[])
{
    //pool
    @autoreleasepool
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"launch daemon %@ started with %@", NSProcessInfo.processInfo.arguments.firstObject.lastPathComponent, NSProcessInfo.processInfo.arguments]);
        
        //init crash reporting
        [SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
            options.dsn = SENTRY_DSN;
            options.debug = YES;
        }];
        
        //not root?
        if(0 != geteuid())
        {
           //err msg
           logMsg(LOG_ERR, [NSString stringWithFormat:@"launch daemon must be run as root, not %d", geteuid()]);
           
           //bail
           goto bail;
        }
        
        //init logging
        if(YES != initLogging(logFilePath()))
        {
            //err msg
            logMsg(LOG_ERR, @"failed to init logging");
            
            //bail
            goto bail;
        }
        
        //alloc/init/load prefs
        preferences = [[Preferences alloc] init];
        if(nil == preferences)
        {
            //err msg
            logMsg(LOG_ERR, @"failed to init/load preferences");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded preferences: %@", preferences.preferences]);
        
        //alloc/init alerts object
        events = [[Events alloc] init];
        
        //alloc/init rules object
        rules = [[Rules alloc] init];
        
        //register for shutdown
        // so can close logging, etc...
        register4Shutdown();
        
        //dbg msg
        logMsg(LOG_DEBUG, @"registered for shutdown events");
        
        //alloc/init XPC comms object
        xpcListener = [[XPCListener alloc] init];
        if(nil == xpcListener)
        {
            //err msg
            logMsg(LOG_ERR, @"failed to initialize XPC listener for user connections");
            
            //bail
            goto bail;
        }

        //dbg msg
        logMsg(LOG_DEBUG, @"created client XPC listener");
        
        //check for FDA
        // wait till we have it!
        // do this after prefs and XPC so install/app can check!
        while(0 != fdaCheck())
        {
            //err msg
            logMsg(LOG_ERR, @"full disk access: denied");
            
            //update preferences
            [preferences update:@{PREF_GOT_FDA:@NO}];
            
            //nap
            [NSThread sleepForTimeInterval:0.50];
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"full disk access: ok");
        
        //update preferences
        [preferences update:@{PREF_GOT_FDA:@YES}];
        
        //load rules
        if(YES != [rules load])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to load rules from %@", RULES_FILE]);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"loaded rules");
    
        //create/init (file) monitor
        monitor = [[Monitor alloc] init];
        
        //prefs say, 'enabled'?
        if(YES != [preferences.preferences[PREF_IS_DISABLED] boolValue])
        {
            //go go go
            if(YES != [monitor start])
            {
               //err msg
               logMsg(LOG_ERR, @"failed to initialize (file) monitor");
               
               //bail
               goto bail;
            }
            
            //dbg msg
            logMsg(LOG_DEBUG, @"monitoring for file events");
        }
        //user (prev) disabled
        // just log this fact, and don't start it
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"user has disabled BlockBlock, so, not enabling");
        }
        
        //run loop
        [[NSRunLoop currentRunLoop] run];
    
bail:
    
    //dbg msg
    logMsg(LOG_DEBUG, @"launch daemon exiting");
            
    //bye!
    goodbye();
        
    }//pool
    
    return 0;
}

//check for full disk access via ESF
// returns -1/0, as main() will return this too...
int fdaCheck()
{
    //isse in ESF pre 10.15.4(?0
    NSOperatingSystemVersion minimumSupportedOSVersion = { .majorVersion = 10, .minorVersion = 15, .patchVersion = 4 };
    
    //status
    int status = -1;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"performing full disk access check...");
    
    //client
    es_client_t *client = nil;
    
    //result
    es_new_client_result_t result = 0;
    
    //try create a client
    // will fail with ES_NEW_CLIENT_RESULT_ERR_NOT_PERMITTED if we don't have FDA
    result = es_new_client(&client, ^(es_client_t *client, const es_message_t *message) {});
    if(ES_NEW_CLIENT_RESULT_SUCCESS == result)
    {
        //happy
        status = 0;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"result: %d/%d", result, status]);
    
    //cleanup client
    // need extra checks for issues with ESF :|
    if(nil != client)
    {
        //can't cleanup client on error older versions of 10.15
        // see: https://twitter.com/patrickwardle/status/1250337659022532610
        if( (ES_NEW_CLIENT_RESULT_SUCCESS == status) ||
            (YES == [NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:minimumSupportedOSVersion]) )
        {
            //free
            es_delete_client(client);
            
            //unset
            client = nil;
        }
    }
    
    return status;
}

//close login
void goodbye()
{
    //close logging
    deinitLogging();
    
    return;
}

//init a handler for SIGTERM
// can perform actions such as disabling firewall and closing logging
void register4Shutdown()
{
    //ignore sigterm
    // handling it via GCD dispatch
    signal(SIGTERM, SIG_IGN);
    
    //init dispatch source for SIGTERM
    dispatchSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, dispatch_get_main_queue());
    
    //set handler
    // ...(just) closes logging
    dispatch_source_set_event_handler(dispatchSource, ^{
        
        //dbg msg
        logMsg(LOG_DEBUG, @"caught 'SIGTERM' message....shutting down");
        
        //bye!
        // close logging
        goodbye();
        
        //bye bye!
        exit(SIGTERM);
    });
    
    //resume
    dispatch_resume(dispatchSource);

    return;
}
