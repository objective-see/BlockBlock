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
#import "Utilities.h"
#import "BTMMonitor.h"
#import "PluginBase.h"

/* GLOBALS */

extern Monitor* monitor;

@implementation BTMMonitor

//start BTM monitoring
// and process BTM events
-(BOOL)start:(PluginBase*)plugin
{
    //flag
    BOOL started = NO;
    
    //result
    es_new_client_result_t result = 0;
    
    //events
    es_event_type_t btmESEvents[] = {ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_ADD};
    
    //dbg msg
    logMsg(LOG_DEBUG, @"starting 'BTM' monitor...");
    
    //create client
    // and handle btm events
    result = es_new_client(&_endpointClient, ^(es_client_t *client, const es_message_t *message)
    {
        //file obj
        File* file = nil;
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"new 'btm' event: %#x", message->event_type]);
        
        //sanity check
        if(ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_ADD != message->event_type)
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"ignoring non-'ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_ADD' event");
            
            return;
        }
        
        //init file obj
        file = [[File alloc] init:(es_message_t *)message csOption:csNone];
        if(nil == file)
        {
            //err msg
            logMsg(LOG_ERR, @"failed to create file object for 'btm' event");
            
            return;
        }
        
        //TODO: test for both launch and login items
        
        //set source path
        // this is the plist for the launch item
        file.destinationPath = convertStringToken(&message->event.btm_launch_item_add->item->item_url);
        
        //process event
        // passing in (btm) plugin
        [monitor processEvent:file plugin:plugin message:es_copy_message(message)];
       
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
    if(ES_RETURN_SUCCESS != es_subscribe(self.endpointClient, btmESEvents, sizeof(btmESEvents)/sizeof(btmESEvents[0])))
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

//stop
-(BOOL)stop
{
    //flag
    BOOL stopped = NO;
    
    //sync
    @synchronized (self) {
        
        //dbg msg
        logMsg(LOG_DEBUG, @"stopping btm monitor...");
            
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
        logMsg(LOG_DEBUG, @"unsubscribed from btm events");
           
        //delete client
        if(ES_RETURN_SUCCESS != es_delete_client(self.endpointClient))
        {
           //err msg
           logMsg(LOG_ERR, @"'es_delete_client' failed");
           
           //bail
           goto bail;
        }
            
        //dbg msg
        logMsg(LOG_DEBUG, @"deleted btm endpoint client");
           
        //unset
        self.endpointClient = NULL;
           
        //happy
        stopped = YES;
            
    }//sync
    
bail:
    
    return stopped;
}

@end
