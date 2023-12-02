//
//  Monitor.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Monitor.h"

#import "Events.h"
#import "utilities.h"
#import "Preferences.h"

#import "Processes.h"
#import "ProcessMonitor.h"

/* GLOBALS */

extern Events* events;
extern Monitor* monitor;
extern Preferences* preferences;

@implementation ProcessMonitor

//start process monitor
// and respond to process events
-(BOOL)start:(PluginBase*)plugin
{
    //flag
    BOOL started = NO;
    
    //result
    es_new_client_result_t result = 0;
    
    //events
    es_event_type_t procESEvents[] = {ES_EVENT_TYPE_AUTH_EXEC};
    
    //dbg msg
    logMsg(LOG_DEBUG, @"starting process monitor...");
    
    //create client
    // and handle process (auth exec) events
    result = es_new_client(&_endpointClient, ^(es_client_t *client, const es_message_t *message)
    {
        //event
        Event* event = nil;
        
        //new process event
        Process* process = nil;
        
        //esf deadline
        uint64_t deadline = 0;
        
        //deadline sema
        dispatch_semaphore_t deadlineSema = 0;
        
        //dbg msg
        //logMsg(LOG_DEBUG, @"new ES_EVENT_TYPE_AUTH_EXEC event");
        
        //check prefs
        // allow if passive mode, or not in notarization mode
        if( (YES == [preferences.preferences[PREF_PASSIVE_MODE] boolValue]) ||
            (YES != [preferences.preferences[PREF_NOTARIZATION_MODE] boolValue]) )
        {
            //dbg msg
            //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"allowing process, due to preferences (%@)", preferences.preferences]);
            
            //allow
            if(YES != [self allowProcessEvent:client message:(es_message_t*)message])
            {
                //err msg
                logMsg(LOG_ERR, @"failed to allow process");
            }
            
            //done
            return;
        }
        
        //init process obj
        process = [[Process alloc] init:(es_message_t* _Nonnull)message csOption:csDynamic];
        if( (nil == process) ||
            (YES == [plugin shouldIgnore:process message:(es_message_t *)message]) )
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"allowing %@", process]);
            
            //allow
            if(YES != [self allowProcessEvent:client message:(es_message_t*)message])
            {
                //err msg
                logMsg(LOG_ERR, @"failed to allow process");
            }
            
            //done
            return;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"alerting user about: %@", process]);
        
        //init event
        event = [[Event alloc] init:process plugin:plugin];
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"alerting user w/: %@", event]);
        
        //add client
        event.esClient = client;
        
        //add msg
        event.esMessage = es_copy_message(message);
        
        //create deadline semaphore
        deadlineSema = dispatch_semaphore_create(0);
        
        //init deadline
        deadline = message->deadline - mach_absolute_time();
        
        //add to event
        event.esSemaphore = deadlineSema;
        
        //background
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        
        //deliver alert
        // can fail if no client
        if(YES == [events deliver:event])
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"alert delivered, waiting for response...");
            
            //wait till close to timeout
            // if haven't hit, just allow, otherwise we'll be killed
            if(0 != dispatch_semaphore_wait(deadlineSema, dispatch_time(DISPATCH_TIME_NOW, machTimeToNanoseconds(deadline) - (1 * NSEC_PER_SEC))))
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"es timeout (%llx seconds) about to be hit, forced to allow process :/", machTimeToNanoseconds(deadline) / NSEC_PER_SEC]);
                
                //sync
                @synchronized(self)
                {
                    //allow
                    if(YES != [self allowProcessEvent:client message:(es_message_t*)message])
                    {
                        //err msg
                        logMsg(LOG_ERR, @"failed to allow process");
                    }
                    
                    //unset
                    event.esClient = NULL;
                    
                    //free
                    es_free_message(event.esMessage);
                    event.esMessage = NULL;
                }
            }
            //sema signal'd
            // handled by user, all good
            else
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"esf semaphore signaled, alert was handled");
            }
        }
        //failed to deliver
        // will just allow process
        else
        {
            //err msg
            logMsg(LOG_ERR, @"failed to deliver message, will allow process :/");
            
            //sync
            @synchronized(self)
            {
                //allow
                if(YES != [self allowProcessEvent:client message:(es_message_t*)message])
                {
                    //err msg
                    logMsg(LOG_ERR, @"failed to allow process");
                }
                
                //unset
                event.esClient = NULL;
                
                //free
                es_free_message(event.esMessage);
                event.esMessage = NULL;
            }
        }
            
        });
    });
    
    //sanity check
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"'es_new_client' failed with %x", result]);
        
        //bail
        goto bail;
    }
    
    //subscribe
    if(ES_RETURN_SUCCESS != es_subscribe(self.endpointClient, procESEvents, sizeof(procESEvents)/sizeof(procESEvents[0])))
    {
        //err msg
        logMsg(LOG_ERR, @"'es_subscribe' failed");
        
        //bail
        goto bail;
    }

    //happy
    started = YES;
    
bail:
    
    return started;
}

//allow process event
-(BOOL)allowProcessEvent:(es_client_t*)client message:(es_message_t*)message
{
    //flag
    BOOL allowed = NO;
    
    //result
    __block es_respond_result_t result = !ES_RESPOND_RESULT_SUCCESS;
    
    //allow
    result = es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false);
    if(ES_RESPOND_RESULT_SUCCESS != result)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"'es_respond_auth_result' failed with %x", result]);
        
        //bail
        goto bail;
    }
    
    //happy
    allowed = YES;
    
bail:
    
    return allowed;
}

//start process monitor
-(BOOL)stop
{
    //flag
    BOOL stopped = NO;
    
    //sync
    @synchronized (self) {
        
        //dbg msg
        logMsg(LOG_DEBUG, @"stopping process monitor...");
            
        //sanity check
        if(NULL == self.endpointClient) goto bail;
        
        //unsubscribe
        if(ES_RETURN_SUCCESS != es_unsubscribe_all(self.endpointClient))
        {
           //err msg
           logMsg(LOG_ERR, @"'es_unsubscribe_all' failed");
           
           //bail
           goto bail;
        }
            
        //dbg msg
        logMsg(LOG_DEBUG, @"unsubscribed from process events");
           
        //delete client
        if(ES_RETURN_SUCCESS != es_delete_client(self.endpointClient))
        {
           //err msg
           logMsg(LOG_ERR, @"'es_delete_client' failed");
           
           //bail
           goto bail;
        }
            
        //dbg msg
        logMsg(LOG_DEBUG, @"deleted process endpoint client");
           
        //unset
        self.endpointClient = NULL;
           
        //happy
        stopped = YES;
            
    }//sync
    
bail:
    
    return stopped;
}

@end
