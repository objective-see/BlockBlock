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

#import <Foundation/Foundation.h>
#import <Security/AuthSession.h>

@interface Event : NSObject
{
    
}

/* PROPERTIES */

//file object
// that matched
@property(nonatomic, retain)File* file;

//plugin
@property(nonatomic, retain)PluginBase* plugin;

//(startup) item
@property(nonatomic, retain)Item* item;

//(user) action
@property NSUInteger action;

//(user) scope
@property NSInteger scope;

/* METHODS */

//init
-(id)init:(File*)file plugin:(PluginBase*)plugin;

//determines if a event is related
// checks things like process path, plugins, paths, etc
-(BOOL)isRelated:(Event*)lastEvent;

//create an (deliverable) obj
-(NSMutableDictionary*)toAlert;

/* PROPERTIES */

//uuid
@property (nonatomic, retain)NSString* uuid;

//time stamp
@property (nonatomic, retain)NSDate *timestamp;

@end
