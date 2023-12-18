//
//  Btm.m
//  BlockBlock
//
//  Created by Patrick Wardle on 11/29/22.
//  Copyright (c) 2022 Objective-See. All rights reserved.
//

#import "Btm.h"
#import "Item.h"
#import "Event.h"
#import "Consts.h"
#import "Launchd.h"
#import "Logging.h"
#import "LoginItem.h"
#import "Utilities.h"
#import "XPCUserClient.h"

//user client
extern XPCUserClient* xpcUserClient;


@implementation Btm

//init
-(id)initWithParams:(NSDictionary*)watchItemInfo
{
    //init super
    self = [super initWithParams:watchItemInfo];
    if(nil != self)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"init'ing %@ (%p)", NSStringFromClass([self class]), self]);
    
        //set type
        self.type = PLUGIN_TYPE_BACKGROUND_TASK;
    }

    return self;
}

//(customize) alert message
// either launch or login item
-(NSString*)alertMessage:(Event*)event
{
    //alert msg
    NSString* alert = nil;
    
    //init to default
    alert = self.alertMsg;
    
    //init alert based on btm type
    switch(event.esMessage->event.btm_launch_item_add->item->item_type)
    {
        //user item
        //case ES_BTM_ITEM_TYPE_USER_ITEM:
        //    alert = @"installed a user item";
        //    break;
        
        //app / login item
        case ES_BTM_ITEM_TYPE_APP:
        case ES_BTM_ITEM_TYPE_LOGIN_ITEM:
            alert = @"installed login item";
            break;
            
        //launch agent
        case ES_BTM_ITEM_TYPE_AGENT:
            alert = @"installed a launch agent";
            break;
            
        //launch daemon
        case ES_BTM_ITEM_TYPE_DAEMON:
            alert = @"installed a launch daemon";
            break;
            
        default:
            ;
    }

    return alert;
}

//get the name of item
-(NSString*)itemName:(Event*)event
{
    //get name from path
    return [[self itemObject:event] lastPathComponent];
}

//get the binary (path) of the item
-(NSString*)itemObject:(Event*)event
{
    //object
    NSString* itemObject = NULL;
    
    //string token
    NSString* stringToken = NULL;
    
    //for launch items
    // ...item found in 'executable_path'
    if( (ES_BTM_ITEM_TYPE_AGENT == event.esMessage->event.btm_launch_item_add->item->item_type) ||
        (ES_BTM_ITEM_TYPE_DAEMON == event.esMessage->event.btm_launch_item_add->item->item_type) )
    {
        //extract/convert
        itemObject = convertStringToken(&event.esMessage->event.btm_launch_item_add->executable_path);
    }
    
    //for login items
    // ...item found in 'item_url'
    else
    {
        //extract convert
        // but its a URL, so just want it's path
        stringToken = convertStringToken(&event.esMessage->event.btm_launch_item_add->item->item_url);
        if(nil != stringToken)
        {
            //extract path
            itemObject = [[NSURL URLWithString:stringToken] path];
        }
    }
    
    return itemObject;
}

//should ignore?
// for now, only ES_BTM_ITEM_TYPE_USER_ITEM events
-(BOOL)shouldIgnore:(File*)file message:(es_message_t *)message
{
    //flag
    BOOL shouldIgnore = NO;
    
    //sanity check
    if(NULL == message)
    {
        //bail
        goto bail;
    }
    
    //for now
    // don't support 'ES_BTM_ITEM_TYPE_USER_ITEM'
    if(ES_BTM_ITEM_TYPE_USER_ITEM == message->event.btm_launch_item_add->item->item_type)
    {
        //should ignore
        shouldIgnore = YES;
    }
    
bail:

    return shouldIgnore;
}

//block btm item
// basically just call into launch or login item to block
-(BOOL)block:(Event*)event
{
    //flag
    __block BOOL wasBlocked = NO;
    
    //handle item specific blocking
    switch(event.esMessage->event.btm_launch_item_add->item->item_type)
    {
        //login item
        case ES_BTM_ITEM_TYPE_APP:
        case ES_BTM_ITEM_TYPE_LOGIN_ITEM:
        {
            //login item obj
            LoginItem* loginItem = nil;
            
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"blocking login item: %@", event.item.object]);
            
            //init login item obj
            loginItem = [[LoginItem alloc] init];
            
            //block
            wasBlocked = [loginItem block:event];
            
            break;
        }
            
        //launch agent
        case ES_BTM_ITEM_TYPE_AGENT:
        case ES_BTM_ITEM_TYPE_DAEMON:
        {
            //launch item obj
            Launchd* launchItem = nil;
            
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"blocking launch item: %@", event.item.object]);
            
            //init launch item obj
            launchItem = [[Launchd alloc] init];
            
            //block
            wasBlocked = [launchItem block:event];
            
            break;
        }
            
        //unsupported type
        default:
         
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"%x is (currently) an unsupported type to block", event.esMessage->event.btm_launch_item_add->item->item_type]);
            
            ;
    }
    
    return wasBlocked;
}

@end
