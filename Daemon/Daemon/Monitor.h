//
//  Watcher.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Event.h"
#import "FileMonitor.h"

@interface Monitor : NSObject
{

}

/* PROPERTIES */

//file monitor
@property(atomic, retain)FileMonitor* fileMon;

//plugin (objects)
@property (nonatomic, retain)NSMutableArray* plugins;

//last event
@property (nonatomic, retain)Event* lastEvent;

//observer for new client/user
@property(nonatomic, retain)id userObserver;


/* METHODS */

//load watch list and enable watches
-(BOOL)start;

//stop
-(BOOL)stop;

@end
