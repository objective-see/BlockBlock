//
//  CronJob.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2020 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../PluginBase.h"

@interface CronJob : PluginBase
{
    
}

/* PROPERTIES */

//watch path
@property(nonatomic, retain)NSString* watchPath;

//list or prev/orginal cron jobs
@property(nonatomic, retain)NSMutableDictionary* snapshot;

/* METHODS */

//update list of saved jobs
-(void)snapshot:(NSString*)path;

@end
