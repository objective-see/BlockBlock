//
//  file: main.m
//  project: BlockBlock (launch daemon)
//  description: main interface/entry point for launch daemon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

/* VIEW (STREAM) LOG */
// log stream --level debug --predicate="subsystem='com.objective-see.blockblock'"

#import "main.h"
#import "Monitor.h"

@import OSLog;

/* GLOBALS */

//(file)monitor
Monitor* monitor = nil;

//log handle
os_log_t logHandle = nil;

//main
// init & kickoff stuffz
int main(int argc, const char * argv[])
{
    //pool
    @autoreleasepool
    {
        //init log
        logHandle = os_log_create(BUNDLE_ID, "daemon");
        
        //dbg msg
        os_log_debug(logHandle, "daemon %{public}@ started with %{public}@", NSProcessInfo.processInfo.arguments.firstObject.lastPathComponent, NSProcessInfo.processInfo.arguments);
    
        //not root?
        if(0 != geteuid())
        {
            //err msg
            os_log_error(logHandle, "ERROR: launch daemon must be run as root, not %d", geteuid());
            goto bail;
        }
        
        //alloc/init/load prefs
        preferences = [[Preferences alloc] init];
        if(nil == preferences)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to init/load preferences");
            goto bail;
        }
        
        //dbg msg
        os_log_debug(logHandle, "loaded preferences: %{public}@", preferences.preferences);
        
        //alloc/init alerts object
        events = [[Events alloc] init];
        
        //alloc/init rules object
        rules = [[Rules alloc] init];
        
        //alloc/init XPC comms object
        xpcListener = [[XPCListener alloc] init];
        if(nil == xpcListener)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to initialize XPC listener for user connections");
            goto bail;
        }

        //dbg msg
        os_log_debug(logHandle, "created client XPC listener");
        
        //check for FDA
        // wait till we have it!
        // do this after prefs and XPC so install/app can check!
        while(0 != fdaCheck())
        {
            //err msg
            os_log_debug(logHandle, "full disk access: denied");
            
            //update preferences
            [preferences update:@{PREF_GOT_FDA:@NO}];
            
            //nap
            [NSThread sleepForTimeInterval:0.50];
        }
        
        //dbg msg
        os_log_debug(logHandle, "full disk access: ok");
        
        //update preferences
        [preferences update:@{PREF_GOT_FDA:@YES}];
        
        //load rules
        if(YES != [rules load])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to load rules from %{public}@", RULES_FILE);
            goto bail;
        }
        
        //dbg msg
        os_log_debug(logHandle, "loaded rules");
    
        //create/init (file) monitor
        monitor = [[Monitor alloc] init];
        
        //prefs say, 'enabled'?
        if(YES != [preferences.preferences[PREF_IS_DISABLED] boolValue])
        {
            //go go go
            if(YES != [monitor start])
            {
                //err msg
                os_log_error(logHandle, "ERROR: failed to initialize (file) monitor");
                goto bail;
            }
            
            //dbg msg
            os_log_debug(logHandle, "monitoring for file events");
        }
        //user (prev) disabled
        // just log this fact, and don't start it
        else
        {
            //dbg msg
            os_log_debug(logHandle, "user has disabled BlockBlock, so, not enabling");
        }
        
        //run loop
        [[NSRunLoop currentRunLoop] run];
    
bail:
    
    //dbg msg
    os_log_debug(logHandle, "launch daemon exiting");
            
    }//pool
    
    return 0;
}

//check for full disk access via ESF
// returns -1/0, as main() will return this too...
int fdaCheck(void)
{
    //issue in ESF pre 10.15.4
    NSOperatingSystemVersion minimumSupportedOSVersion = { .majorVersion = 10, .minorVersion = 15, .patchVersion = 4 };
    
    //status
    int status = -1;
    
    //dbg msg
    os_log_debug(logHandle, "performing full disk access check via 'es_new_client'...");
    
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
    os_log_debug(logHandle, "'es_new_client' result: %d/%d", result, status);
    
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
