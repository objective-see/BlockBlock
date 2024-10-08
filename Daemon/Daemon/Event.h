//
//  WatchEvent.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/26/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

@class Item;
@class Event;
@class PluginBase;

#import "FileMonitor.h"

@import Foundation;

#import <Security/AuthSession.h>
#import <EndpointSecurity/EndpointSecurity.h>

@interface Event : NSObject
{
    
}

/* PROPERTIES */

//file object
// that matched
@property(nonatomic, retain)File* file;

//process object
@property(nonatomic, retain)Process* process;

//plugin
@property(nonatomic, retain)PluginBase* plugin;

//(startup) item
@property(nonatomic, retain)Item* item;

//esf client
@property es_client_t* esClient;

//esf message
@property es_message_t* esMessage;

//esf sema
@property dispatch_semaphore_t esSemaphore;

//(user) action
@property NSUInteger action;

//(user) scope
@property NSInteger scope;

/* METHODS */

//init
-(id)init:(id)object plugin:(PluginBase*)plugin;

//determines if a event is related
// checks things like process path, plugins, paths, etc
-(BOOL)isRelated:(Event*)lastEvent includeTime:(BOOL)includeTime;

//create an (deliverable) obj
-(NSMutableDictionary*)toAlert;

/* PROPERTIES */

//uuid
@property (nonatomic, retain)NSString* uuid;

//time stamp
@property (nonatomic, retain)NSDate *timestamp;

@end
