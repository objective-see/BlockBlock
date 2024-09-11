//
//  FileMonitor.m
//  FileMonitor
//
//  Created by Patrick Wardle on 9/1/19.
//  Copyright © 2020 Objective-See. All rights reserved.
//

//  Inspired by https://gist.github.com/Omar-Ikram/8e6721d8e83a3da69b31d4c2612a68ba
//  NOTE: requires a) root b) the 'com.apple.developer.endpoint-security.client' entitlement

#import "FileMonitor.h"
#import "utilities.h"

#import <dlfcn.h>
#import <Foundation/Foundation.h>
#import <EndpointSecurity/EndpointSecurity.h>

/* GLOBALS */

//endpoint client
es_client_t* endpointClient = nil;

//pointer to function
// responsibility_get_pid_responsible_for_pid()
pid_t (*getRPID)(pid_t pid) = NULL;

//process cache
NSCache* _Nonnull processCache;

//processes cache
NSCache* _Nonnull processesCache;

@interface FileMonitor ()

//process args (via `ES_EVENT_TYPE_NOTIFY_EXEC`)
// so save, to report with all other file i/o events
@property(atomic, retain)NSMutableDictionary* arguments;

@end

@implementation FileMonitor

//args
@synthesize arguments;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc agrugments dictionary
        arguments = [NSMutableDictionary dictionary];
        
        //get function pointer
        getRPID = dlsym(RTLD_NEXT, "responsibility_get_pid_responsible_for_pid");
        
        //init process cache
        processCache = [[NSCache alloc] init];
        processCache.countLimit = 2048;
        
        //init processes cache
        processesCache = [[NSCache alloc] init];
        processesCache.countLimit = 2048;
    }
    
    return self;
}

//start monitoring
// pass in events of interest, count of said events, and callback
-(BOOL)start:(es_event_type_t*)events count:(uint32_t)count csOption:(NSUInteger)csOption callback:(FileCallbackBlock)callback
{
    //flag
    BOOL started = NO;
    
    //result
    es_new_client_result_t result = 0;
    
    //sync
    @synchronized (self)
    {
    
    //create client
    // callback invoked on file events
    result = es_new_client(&endpointClient, ^(es_client_t *client, const es_message_t *message)
    {
        //new file obj
        File* file = nil;
        
        //init file obj
        // then generate args, code-signing info, etc
        file = [[File alloc] init:(es_message_t* _Nonnull)message csOption:csOption];
        if(nil != file)
        {
            //extract/process args
            // but don't report file event...
            if( (ES_EVENT_TYPE_NOTIFY_EXEC == message->event_type) ||
                (ES_EVENT_TYPE_NOTIFY_EXIT == message->event_type) )
            {
                //process args
                [self processArgs:message file:file];
                
                return;
            }
                
            //add args
            if(nil != self.arguments[[NSNumber numberWithInt:file.process.pid]])
            {
                //add
                file.process.arguments = self.arguments[[NSNumber numberWithInt:file.process.pid]];
            }
        
            //invoke user callback
            callback(file);
        }
    });
    
    //error?
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        //err msg
        NSLog(@"ERROR: es_new_client() failed with %#x", result);
        
        //provide more info
        switch (result) {
                
            //not entitled
            case ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED:
                NSLog(@"ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED: \"The caller is not properly entitled to connect\"");
                break;
                      
            //not permitted
            case ES_NEW_CLIENT_RESULT_ERR_NOT_PERMITTED:
                NSLog(@"ES_NEW_CLIENT_RESULT_ERR_NOT_PERMITTED: \"The caller is not permitted to connect. They lack Transparency, Consent, and Control (TCC) approval form the user.\"");
                break;
                      
            //not privileged
            case ES_NEW_CLIENT_RESULT_ERR_NOT_PRIVILEGED:
                NSLog(@"ES_NEW_CLIENT_RESULT_ERR_NOT_PRIVILEGED: \"The caller is not running as root\"");
                break;
                
            default:
                break;
        }
    
        //bail
        goto bail;
    }
    
    //clear cache
    if(ES_CLEAR_CACHE_RESULT_SUCCESS != es_clear_cache(endpointClient))
    {
        //err msg
        NSLog(@"ERROR: es_clear_cache() failed");
        
        //bail
        goto bail;
    }
    
    //mute self
    // note: you might not want this, but for a cmdline-based filemonitor
    //       this ensures we don't constantly report writes to current /dev/tty
    es_mute_path_literal(endpointClient, [NSProcessInfo.processInfo.arguments[0] UTF8String]);
    
    //subscribe
    if(ES_RETURN_SUCCESS != es_subscribe(endpointClient, events, count))
    {
        //err msg
        NSLog(@"ERROR: es_subscribe() failed");
        
        //bail
        goto bail;
    }
        
    } //sync
    
    //happy
    started = YES;
    
bail:
    
    return started;
}

//process args
-(void)processArgs:(const es_message_t*)message file:(File*)file
{
    //process exec?
    // save arguments
    if( (nil != file.process.arguments) &&
        (ES_EVENT_TYPE_NOTIFY_EXEC == message->event_type) )
    {
        //save args
        self.arguments[[NSNumber numberWithInt:file.process.pid]] = file.process.arguments;
    }
    
    //process exit?
    // remove saved process args
    else if(ES_EVENT_TYPE_NOTIFY_EXIT == message->event_type)
    {
        //remove args
        [self.arguments removeObjectForKey:[NSNumber numberWithInt:file.process.pid]];
    }
    
    return;
}

//stop
-(BOOL)stop
{
    //flag
    BOOL stopped = NO;
    
    //sync
    @synchronized (self)
    {
        
    //unsubscribe & delete
    if(NULL != endpointClient)
    {
       //unsubscribe
       if(ES_RETURN_SUCCESS != es_unsubscribe_all(endpointClient))
       {
           //err msg
           NSLog(@"ERROR: es_unsubscribe_all() failed");
           
           //bail
           goto bail;
       }
       
       //delete
       if(ES_RETURN_SUCCESS != es_delete_client(endpointClient))
       {
           //err msg
           NSLog(@"ERROR: es_delete_client() failed");
           
           //bail
           goto bail;
       }
       
       //unset
       endpointClient = NULL;
       
       //happy
       stopped = YES;
    }
        
    } //sync
    
bail:
    
    return stopped;
}

@end
