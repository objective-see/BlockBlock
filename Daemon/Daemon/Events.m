//
//  file: Alerts.m
//  project: BlockBlock (launch daemon)
//  description: alert related logic/tracking
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Item.h"
#import "Event.h"
#import "consts.h"
#import "Events.h"
#import "Monitor.h"
#import "logging.h"
#import "utilities.h"

/* GLOBALS */

//monitor obj
extern Monitor* monitor;

//user client
XPCUserClient* xpcUserClient;

@implementation Events

@synthesize reportedEvents;
@synthesize consoleUser;
@synthesize userObserver;
//@synthesize relatedAlerts;
//@synthesize xpcUserClient;
@synthesize undelivertedAlerts;

//init
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //alloc shown
        reportedEvents = [NSMutableDictionary dictionary];
        
        //alloc undelivered
        undelivertedAlerts = [NSMutableDictionary dictionary];
        
        //init user xpc client
        xpcUserClient = [[XPCUserClient alloc] init];
        
        /*
        //register listener for new client/user (login item)
        // when it fires, deliver any alerts that occured when user wasn't logged in
        self.userObserver = [[NSNotificationCenter defaultCenter] addObserverForName:USER_NOTIFICATION object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
        {
            //grab console user
            self.consoleUser = getConsoleUser();
            
            //TODO: add as feature
            //process alerts
            //[self processUndelivered];
        }];
        */
    }
    
    return self;
}

//add an alert to 'shown'
-(void)addShown:(Event*)event;
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"adding alert to 'shown': %@", event]);
    
    //add alert
    @synchronized(self.reportedEvents)
    {
        //add
        self.reportedEvents[event.uuid] = event;
    }
    
    return;
}

//remove an alert from 'shown'
-(void)removeShown:(Event*)event
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removing alert from 'shown': %@", event]);
    
    //remove alert
    @synchronized(self.reportedEvents)
    {
        //remove
        self.reportedEvents[event.uuid] = nil;
    }
    
    return;
}

//check if (possibly related) alert was already shown
-(BOOL)wasShown:(Event*)event
{
    //flag
    __block BOOL shown = NO;
    
    //sync to check
    @synchronized(self.reportedEvents)
    {
        //any matches?
        [self.reportedEvents enumerateKeysAndObjectsUsingBlock:^(NSString* key, Event* shownEvent, BOOL *stop)
        {
            //related?
            if(YES == [event isRelated:shownEvent])
            {
                //got match
                shown = YES;
                    
                //done
                *stop = YES;
            }
        }];
    }

bail:
    
    return shown;
}

//via XPC, send an alert
-(BOOL)deliver:(Event*)event
{
    //flag
    BOOL delivered = NO;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"delivering alert to user: %@", event]);
    
    //send via XPC to user
    // failure likely means no client, so just allow, but save
    if(YES != [xpcUserClient deliverEvent:event])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"failed to deliver alert to user (no client?)");
        
        //can't deliver
        // ...but should update plugin's snapshot
        [event.plugin snapshot:event.file.destinationPath];
        
        //TODO: add?
        //save undelivered alert
        //[self addUndeliverted:alert];
        
        //bail
        goto bail;
    }
    
    //happy
    delivered = YES;
    
    //save alert
    [self addShown:event];
    
bail:
    
    return delivered;
}

/*
//add an alert 'undelivered'
-(void)addUndeliverted:(NSDictionary*)alert
{
    //path
    NSString* path = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"adding alert to 'undelivered': %@", alert]);
    
    //add alert
    @synchronized(self.undelivertedAlerts)
    {
        //grab path
        path = alert[ALERT_PROCESS_PATH];
        
        //add
        self.undelivertedAlerts[path] = alert;
    }
    
    return;
}
 
*/

/*
//process undelivered alerts
// add to queue, and to 'shown' alert
-(void)processUndelivered
{
    //alert
    NSDictionary* alert = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"processing %lu undelivered alerts", self.undelivertedAlerts.count]);
    
    //sync
    @synchronized(self.undelivertedAlerts)
    {
        //process all undelivered alerts
        // add to queue, and to 'shown' alert
        for(NSString* path in self.undelivertedAlerts.allKeys)
        {
            //grab alert
            alert = self.undelivertedAlerts[path];
            
            //deliver alert
            [self deliver:alert];
    
            //remove
            [self.undelivertedAlerts removeObjectForKey:path];
            
            //save to 'shown'
            [self addShown:event];
        }
    }
    return;
}

*/

@end
