//
//  CronJob.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../PluginBase.h"

@interface CronJob : PluginBase
{
    
}

/* PROPERTIES */



/* METHODS */

//parse cron jobs
// ->but each into an array
-(NSMutableArray*)parseCronJobs:(NSData*)fileData includeComments:(BOOL)includeComments;

/*
//delete a login item via apple script
// ->class instance since invoked by UI instance in user session
+(BOOL)deleteLoginItem:(NSString*)name;

//find's latest login item
// ->diff's original list of login items with current ones
-(NSDictionary*)findLoginItem:(WatchEvent*)watchEvent;

//update the global originals list with contents of login item file
-(void)updateOriginals:(NSString*)path;
 
*/

@end
