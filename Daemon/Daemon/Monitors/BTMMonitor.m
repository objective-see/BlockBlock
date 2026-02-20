//
//  Monitor.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Monitor.h"
#import "Utilities.h"
#import "BTMMonitor.h"
#import "PluginBase.h"

/* GLOBALS */

//monitor
extern Monitor* monitor;

//log handle
extern os_log_t logHandle;

@implementation BTMMonitor

//start BTM monitoring
// and process BTM events
-(BOOL)start:(PluginBase*)btmPlugin
{
    //flag
    BOOL started = NO;
    
    //result
    es_new_client_result_t result = 0;
    
    //events
    es_event_type_t btmESEvents[] = {ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_ADD};
    
    //dbg msg
    os_log_debug(logHandle, "starting 'BTM' monitor...");
    
    //create client
    // and handle btm events
    result = es_new_client(&_endpointClient, ^(es_client_t *client, const es_message_t *message)
    {
        //file obj
        File* file = nil;
        
        //string token
        NSString* stringToken = nil;
        
        //copied message
        es_message_t* messageCopy = NULL;
        
        //dbg msg
        os_log_debug(logHandle, "new 'btm' event: %#x", message->event_type);
        
        //sanity check
        if(ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_ADD != message->event_type)
        {
            //dbg msg
            os_log_debug(logHandle, "ignoring non-'ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_ADD' event");
            
            return;
        }
        
        //init file obj
        file = [[File alloc] init:(es_message_t *)message csOption:csNone];
        if(nil == file)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to create file object for 'btm' event");
            
            return;
        }
        
        //set plist for launch items (agents/daemons)
        if( (ES_BTM_ITEM_TYPE_AGENT == message->event.btm_launch_item_add->item->item_type) ||
            (ES_BTM_ITEM_TYPE_DAEMON == message->event.btm_launch_item_add->item->item_type) )
        {
            //set source path
            // this is the plist for the launch item
            stringToken = convertStringToken(&message->event.btm_launch_item_add->item->item_url);
            if(nil != stringToken)
            {
                file.destinationPath = [[NSURL URLWithString:stringToken] path];
            }
        }
        //login items don't (really) have a startup file that's modified
        else
        {
            file.destinationPath = @"n/a";
        }
        
        //retain message
        if(@available(macOS 11.0, *))
        {
            //retain
            es_retain_message(message);
            messageCopy = (es_message_t *)message;
        }
        //copy message
        else
        {
            //copy
            messageCopy = es_copy_message(message);
        }
        
        //process event
        // passing in (btm) plugin
        [monitor processEvent:file plugin:btmPlugin message:messageCopy];
       
    });
    
    //sanity check
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        //err msg
        os_log_error(logHandle, "ERROR: 'es_new_client' failed with %x", result);
        
        //bail
        goto bail;
    }
    
    //subscribe
    if(ES_RETURN_SUCCESS != es_subscribe(self.endpointClient, btmESEvents, sizeof(btmESEvents)/sizeof(btmESEvents[0])))
    {
        //err msg
        os_log_error(logHandle, "ERROR: 'es_subscribe' failed");
        
        //bail
        goto bail;
    }

    //happy
    started = YES;
    
bail:
    
    return started;

}

//stop
-(BOOL)stop
{
    //flag
    BOOL stopped = NO;
    
    //sync
    @synchronized (self) {
        
        //dbg msg
        os_log_debug(logHandle, "stopping btm monitor...");
            
        //sanity check
        if(NULL == self.endpointClient) goto bail;
        
        //unsubscribe
        if(ES_RETURN_SUCCESS != es_unsubscribe_all(self.endpointClient))
        {
           //err msg
           os_log_error(logHandle, "ERROR: 'es_unsubscribe_all' failed");
           
           //bail
           goto bail;
        }
            
        //dbg msg
        os_log_debug(logHandle, "unsubscribed from btm events");
           
        //delete client
        if(ES_RETURN_SUCCESS != es_delete_client(self.endpointClient))
        {
           //err msg
           os_log_error(logHandle, "ERROR: 'es_delete_client' failed");
           
           //bail
           goto bail;
        }
            
        //dbg msg
        os_log_debug(logHandle, "deleted btm endpoint client");
           
        //unset
        self.endpointClient = NULL;
           
        //happy
        stopped = YES;
            
    }//sync
    
bail:
    
    return stopped;
}

@end
