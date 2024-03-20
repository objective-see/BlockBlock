//
//  Monitor.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

@import Foundation;

#import "Event.h"
#import "FileMonitor.h"

#import "Monitors/BTMMonitor.h"
#import "Monitors/ProcessMonitor.h"

#import <EndpointSecurity/EndpointSecurity.h>

@import OSLog;

@interface Monitor : NSObject
{

}

/* PROPERTIES */

//endpoint (process) client
@property es_client_t* endpointProcessClient;

//file monitor
@property(atomic, retain)FileMonitor* fileMon;

//btm monitor
@property(nonatomic, retain)BTMMonitor* btmMonitor;

//process monitor
@property(nonatomic, retain)ProcessMonitor* processMonitor;

//plugin (objects)
@property (nonatomic, retain)NSMutableArray* plugins;

//last event
@property (nonatomic, retain)Event* lastEvent;

//observer for new client/user
@property(nonatomic, retain)id userObserver;


/* METHODS */

//load watch list and enable watches
-(BOOL)start;

//process event
-(void)processEvent:(File*)file plugin:(PluginBase*)plugin message:(es_message_t*)message;

//stop
-(BOOL)stop;

@end
