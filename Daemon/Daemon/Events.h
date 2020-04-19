//
//  file: Alerts.h
//  project: BlockBlock (launch daemon)
//  description: alert related logic/tracking (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


@class Event;

#import "PluginBase.h"
#import "FileMonitor.h"
#import "XPCUserProto.h"
#import "XPCUserClient.h"

#import <Foundation/Foundation.h>

@interface Events : NSObject

/* PROPERTIES */

//shown events
@property(nonatomic, retain)NSMutableDictionary* reportedEvents;

//related alerts
//@property(nonatomic, retain)NSMutableDictionary* relatedAlerts;

//undeliveryed alerts
@property(nonatomic, retain)NSMutableDictionary* undelivertedAlerts;

//observer for new client/user
@property(nonatomic, retain)id userObserver;

//xpc client for talking to user (login item)
//@property(nonatomic, retain)XPCUserClient* xpcUserClient;

//console user
@property(nonatomic, retain)NSString* consoleUser;

/* METHODS */

//create an alert object
//-(NSMutableDictionary*)create:(Event*)event;

//check if alert was shown
-(BOOL)wasShown:(Event*)event;

//add an alert to 'shown'
-(void)addShown:(Event*)event;

//remove an alert from 'shown'
-(void)removeShown:(Event*)event;

//via XPC, send an alert
-(BOOL)deliver:(Event*)event;

@end
