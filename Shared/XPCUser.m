//
//  file: XPCUser.m
//  project: BlockBlock (login item)
//  description: user XPC methods
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "XPCUser.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "AlertWindowController.h"

/* GLOBALS */

//alert (windows)
extern NSMutableDictionary* alerts;

@implementation XPCUser

//show an alert window
-(void)alertShow:(NSDictionary*)alert
{
    //pool
    @autoreleasepool {
        
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"daemon invoked user XPC method, '%s'", __PRETTY_FUNCTION__]);
    
    //on main (ui) thread
    dispatch_sync(dispatch_get_main_queue(), ^{
    
        //alert window
        AlertWindowController* alertWindow = nil;
        
        //alloc/init alert window
        alertWindow = [[AlertWindowController alloc] initWithWindowNibName:@"AlertWindow"];
        
        //sync to save alert
        // ensures there is a (memory) reference to the window
        @synchronized(alerts)
        {
            //save
            alerts[alert[ALERT_UUID]] = alertWindow;
        }
        
        //set alert
        alertWindow.alert = alert;
        
        //show in all spaces
        alertWindow.window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces;
        
        //show alert window
        [alertWindow showWindow:self];
            
        //'request' user attenion
        // bounces icon on the dock
        [NSApp requestUserAttention:NSInformationalRequest];
        
        //make alert window key
        [alertWindow.window makeKeyAndOrderFront:self];
        
        //set app's background/foreground state
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]) setActivationPolicy];
        
    });
    
    } //pool
    
    return;
}

//for login item enable/disable
// we use the launch services APIs, since replacements don't always work :(
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

//remove login item
-(void)removeLoginItem:(NSURL*)loginItem reply:(void (^)(NSNumber*))reply;
{
    //flag
    BOOL wasRemoved = NO;
    
    //login item ref
    LSSharedFileListRef loginItemsRef = NULL;
    
    //login items
    CFArrayRef loginItems = NULL;
    
    //current login item
    CFURLRef currentLoginItem = NULL;
    
    //get reference to login items
    loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removing login item %@", loginItem]);
        
    //grab existing login items
    loginItems = LSSharedFileListCopySnapshot(loginItemsRef, nil);
        
    //iterate over all login items
    // look for self, then remove it
    for(id item in (__bridge NSArray *)loginItems)
    {
        //get current login item
        currentLoginItem = LSSharedFileListItemCopyResolvedURL((__bridge LSSharedFileListItemRef)item, 0, NULL);
        if(NULL == currentLoginItem)
        {
            //skip
            continue;
        }
        
        //current login item match self?
        if(YES == [(__bridge NSURL *)currentLoginItem isEqual:loginItem])
        {
            //remove
            if(noErr != LSSharedFileListItemRemove(loginItemsRef, (__bridge LSSharedFileListItemRef)item))
            {
                //err msg
                logMsg(LOG_ERR, @"failed to remove login item");
                
                //bail
                goto bail;
            }
            
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removed login item: %@", loginItem]);
            
            //happy
            wasRemoved = YES;
            
            //all done
            goto bail;
        }
        
        //release
        CFRelease(currentLoginItem);
        
        //reset
        currentLoginItem = NULL;
        
    }//all login items
        
bail:
    
    //release login items
    if(NULL != loginItems)
    {
        //release
        CFRelease(loginItems);
        
        //reset
        loginItems = NULL;
    }
    
    //release login ref
    if(NULL != loginItemsRef)
    {
        //release
        CFRelease(loginItemsRef);
        
        //reset
        loginItemsRef = NULL;
    }
    
    //release url
    if(NULL != currentLoginItem)
    {
        //release
        CFRelease(currentLoginItem);
        
        //reset
        currentLoginItem = NULL;
    }
    
    //reply to client
    reply([NSNumber numberWithBool:wasRemoved]);
    
    return;
}



//TODO: add if we want to get fancy

/*

//main app's xpc methods
#ifndef LOGIN_ITEM

//rule changed
// broadcast new rules, so any (relevant) windows can be updated
-(void)rulesChanged:(NSDictionary*)rules
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"daemon invoked user XPC method, '%s'", __PRETTY_FUNCTION__]);
    
    //broadcast
    [[NSNotificationCenter defaultCenter] postNotificationName:RULES_CHANGED object:nil userInfo:@{RULES_CHANGED:rules}];
    
    return;
}

#endif
*/

@end
