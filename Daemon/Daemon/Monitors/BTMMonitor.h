//
//  BTMMonitor.h
//  BlockBlock
//
//  Created by Patrick Wardle on 11/25/14.
//  Copyright (c) 2023 Objective-See. All rights reserved.
//

@import Foundation;

//#import "Event.h"
//#import "BTMMonitor.h"
#import <EndpointSecurity/EndpointSecurity.h>

@interface BTMMonitor : NSObject
{

}

/* PROPERTIES */

//endpoint client
@property es_client_t* endpointClient;


/* METHODS */

//start
-(BOOL)start:(PluginBase*)plugin;

//stop
-(BOOL)stop;

@end
