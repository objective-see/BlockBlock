//
//  Monitor.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

@import OSLog;
@import Foundation;

#import "Event.h"

#import <EndpointSecurity/EndpointSecurity.h>

@interface ProcessMonitor : NSObject
{

}

/* PROPERTIES */

//endpoint client
@property es_client_t* endpointClient;

//cache
@property(nonatomic, retain)NSCache* cache;


/* METHODS */

//start
-(BOOL)start:(PluginBase*)plugin;

//stop
-(BOOL)stop;

@end
