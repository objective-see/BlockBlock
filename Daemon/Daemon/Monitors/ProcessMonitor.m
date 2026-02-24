//
//  Monitor.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Monitor.h"

#import "Events.h"
#import "utilities.h"
#import "Preferences.h"

#import "Processes.h"
#import "ProcessMonitor.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

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
    
    //init cache
    self.cache = [[NSCache alloc] init];
    self.cache.countLimit = 4096;
    
    //dbg msg
    os_log_debug(logHandle, "starting process monitor...");
        
    //create client
    // and handle process (auth exec) events
    result = es_new_client(&_endpointClient, ^(es_client_t *client, const es_message_t *message)
    {
        //flag
        BOOL isAlive = YES;
        
        //event
        Event* event = nil;
        
        //new process event
        Process* process = nil;
        
        //deadline sema
        dispatch_semaphore_t deadlineSema = 0;
        
        //dbg msg
        //os_log_debug(logHandle, "new ES_EVENT_TYPE_AUTH_EXEC event");
        
        //if deadline is super short
        // user won't be able to respond anyways, so just allow :|
        if((machTimeToNanoseconds(message->deadline - mach_absolute_time())) < (2.5 * NSEC_PER_SEC)) {
            
            //allow
            [self allowProcessEvent:client message:(es_message_t*)message cache:false];
            
            //dbg msg
            os_log_debug(logHandle, "ES timeout (%llu seconds) is too short, so allowing process",  machTimeToNanoseconds(message->deadline - mach_absolute_time()) / NSEC_PER_SEC);
            
            //done
            return;
        }
        
        //notarization mode off?
        // process is irrelvant, so allow (and cache)
        if(![preferences.preferences[PREF_NOTARIZATION_MODE] boolValue]) {
            
            //dbg msg
            //os_log_debug(logHandle, "allowing process, due to preferences (%{public}@)", preferences.preferences]);
            
            [self allowProcessEvent:client message:(es_message_t*)message cache:true];
            return;
        }
    
        //init process obj
        process = [[Process alloc] init:(es_message_t* _Nonnull)message csOption:csDynamic];
        if(!process) {
            
            os_log_error(logHandle, "failed to create process object");
            [self allowProcessEvent:client message:(es_message_t*)message cache:false];

            return;
        }
        
        //allow?
        // and cache
        if([plugin shouldIgnore:process message:(es_message_t *)message]) {
            
            os_log_debug(logHandle, "allowing (and caching) %{public}@", process);
            [self allowProcessEvent:client message:(es_message_t*)message cache:true];

            return;
        }
        
        //ignore if dead now
        //when macOS kills a process we still get an event, so handle this case
        for(int i=0; i<3; i++)
        {
            if(!isProcessAlive(process.pid)) {
                os_log_debug(logHandle, "process died, so will ignore");
                [self allowProcessEvent:client message:(es_message_t*)message cache:false];
                return;
            }
            
            [NSThread sleepForTimeInterval:0.05];
        }
      
        /* from here on, we're going to ask user
           ...even in passive mode (killing processes w/o user input isn't ideal) */
        
        //dbg msg
        os_log_debug(logHandle, "alerting user about: %{public}@", process);
        
        //init event
        event = [[Event alloc] init:process plugin:plugin];
        
        //dbg msg
        os_log_debug(logHandle, "alerting user w/: %{public}@", event);
        
        //add client
        event.esClient = client;
        
        //retain message
        if(@available(macOS 11.0, *))
        {
            //retain
            es_retain_message(message);
            event.esMessage = (es_message_t*)message;
        }
        //copy message
        else
        {
            //copy
            event.esMessage = es_copy_message(message);
        }
        
        //create deadline semaphore
        deadlineSema = dispatch_semaphore_create(0);
        
        //add to event
        event.esSemaphore = deadlineSema;
        
        //deliver alert
        // can fail if no client
        if(YES == [events deliver:event])
        {
            //dbg msg
            os_log_debug(logHandle, "alert delivered, waiting for response...");
            
            //wait time
            // note: we've already checked to make sure it's at least 2.5 seconds
            uint64_t waitTime = machTimeToNanoseconds(message->deadline - mach_absolute_time()) - (2.0 * NSEC_PER_SEC);
            
            //wait till close to timeout
            // if haven't hit, just allow, otherwise we'll be killed
            if(0 != dispatch_semaphore_wait(deadlineSema, dispatch_time(DISPATCH_TIME_NOW, waitTime)))
            {
                //err msg
                os_log_error(logHandle, "ERROR: ES timeout (%llu seconds) about to be hit, forced to allow process", waitTime / NSEC_PER_SEC);
                
                //sync
                @synchronized(self)
                {
                    //allow
                    if(YES != [self allowProcessEvent:client message:(es_message_t*)message cache:NO])
                    {
                        //err msg
                        os_log_error(logHandle, "ERROR: failed to allow process");
                    }
                    
                    //sync
                    @synchronized (event) {
                        
                        //unset
                        event.esClient = NULL;
                        
                        //release message
                        if(@available(macOS 11.0, *))
                        {
                            //release
                            if(NULL != event.esMessage)
                            {
                                es_release_message(event.esMessage);
                            }
                        }
                        //free message
                        else
                        {
                            //free
                            if(NULL != event.esMessage)
                            {
                                //free
                                es_free_message(event.esMessage);
                            }
                        }
                        
                        //unset
                        event.esMessage = NULL;
                    }
                }
            }
            //sema signal'd
            // handled by user, all good
            else
            {
                //dbg msg
                os_log_debug(logHandle, "esf semaphore signaled, alert was handled");
            }
        }
        //failed to deliver
        // will just allow process
        else
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to deliver message, will allow process :/");
            
            //sync
            @synchronized(self)
            {
                //allow
                if(YES != [self allowProcessEvent:client message:(es_message_t*)message cache:NO])
                {
                    //err msg
                    os_log_error(logHandle, "ERROR: failed to allow process");
                }
                
                //sync
                @synchronized(event) {
                    
                    //unset
                    event.esClient = NULL;
                    
                    //release message
                    if(@available(macOS 11.0, *))
                    {
                        //release
                        if(NULL != event.esMessage)
                        {
                            es_release_message(event.esMessage);
                        }
                    }
                    //free message
                    else
                    {
                        //free
                        if(NULL != event.esMessage)
                        {
                            es_free_message(event.esMessage);
                        }
                    }
                    
                    //unset
                    event.esMessage = NULL;
                }
            }
        }
            
    });
   
    //sanity check
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        //err msg
        os_log_error(logHandle, "ERROR: 'es_new_client' failed with %x", result);
        goto bail;
    }
    
    //subscribe
    if(ES_RETURN_SUCCESS != es_subscribe(self.endpointClient, procESEvents, sizeof(procESEvents)/sizeof(procESEvents[0])))
    {
        //err msg
        os_log_error(logHandle, "ERROR: 'es_subscribe' failed");
        goto bail;
    }
    
    //set flag
    self.isRunning = YES;

    //happy
    started = YES;
    
bail:
    
    return started;
}

//allow process event
-(BOOL)allowProcessEvent:(es_client_t*)client message:(es_message_t*)message cache:(bool)cache
{
    //flag
    BOOL allowed = NO;
    
    //result
    es_respond_result_t result = !ES_RESPOND_RESULT_SUCCESS;
    
    //script?
    // don't cache
    if( (message->version >= 2) &&
        (ES_EVENT_TYPE_AUTH_EXEC == message->event_type) )
    {
        //has script?
        if(NULL != message->event.exec.script)
        {
            //set flag
            cache = NO;
        }
    }

    //allow
    result = es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, cache);
    if(ES_RESPOND_RESULT_SUCCESS != result)
    {
        //err msg
        os_log_error(logHandle, "ERROR: 'es_respond_auth_result' failed with %x", result);
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
        os_log_debug(logHandle, "stopping process monitor...");
            
        //sanity check
        if(NULL == self.endpointClient) goto bail;
        
        //unsubscribe
        if(ES_RETURN_SUCCESS != es_unsubscribe_all(self.endpointClient))
        {
           //err msg
           os_log_error(logHandle, "ERROR: 'es_unsubscribe_all' failed");
           goto bail;
        }
            
        //dbg msg
        os_log_debug(logHandle, "unsubscribed from process events");
           
        //delete client
        if(ES_RETURN_SUCCESS != es_delete_client(self.endpointClient))
        {
           //err msg
           os_log_error(logHandle, "ERROR: 'es_delete_client' failed");
           goto bail;
        }
            
        //dbg msg
        os_log_debug(logHandle, "deleted process endpoint client");
           
        //unset
        self.endpointClient = NULL;
           
        //happy
        stopped = YES;
            
    }//sync
    
    //set flag
    self.isRunning = YES;
    
bail:
    
    return stopped;
}

//clear (ES) cache
-(void)clearCache
{
    //dbg msg
    os_log_debug(logHandle, "'%s' invoked", __PRETTY_FUNCTION__);
    
    //sync to clear
    @synchronized (self)
    {
        //clear cache
        if(NULL != self.endpointClient)
        {
            //clear
            es_clear_cache(self.endpointClient);
        }
    }
    return;
}

@end
