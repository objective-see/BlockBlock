//
//  CronJob.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2020 Objective-See. All rights reserved.
//

#import "Item.h"
#import "Event.h"
#import "Consts.h"
#import "CronJob.h"
#import "Logging.h"
#import "Utilities.h"
#import "XPCUserClient.h"

@implementation CronJob

@synthesize snapshot;
@synthesize watchPath;

//init
-(id)initWithParams:(NSDictionary*)watchItemInfo
{
    //init super
    // not need to init super's params
    self = [super init];
    if(nil != self)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"init'ing %@ (%p)", NSStringFromClass([self class]), self]);
        
        //set type
        self.type = PLUGIN_TYPE_CRON_JOB;
        
        //save description from plugin's .plist
        self.description = watchItemInfo[@"description"];
        
        //save alert msg from plugin's .plist
        self.alertMsg = watchItemInfo[@"alert"];
        
        //extract watch path
        // only one for cron jobs
        self.watchPath = [watchItemInfo[@"paths"] firstObject];
        
        //alloc dictionary for snapshot
        snapshot = [NSMutableDictionary dictionary];
        
        //init all snapshots
        // for all (existing) crob job files
        for(NSString* path in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.watchPath error:nil])
        {
            //update
            [self snapshot:[self.watchPath stringByAppendingPathComponent:path]];
        }
    }

    return self;
}

//is a file a match?
// just check if file has prefix
-(BOOL)isMatch:(File*)file
{
    //has prefix?
    return [file.destinationPath hasPrefix:self.watchPath];
}

//check cron jobs
// was a new one added?
-(BOOL)shouldIgnore:(File*)file
{
    //flag
    // default to ignore
    BOOL shouldIgnore = YES;
 
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"'%s' invoked", __PRETTY_FUNCTION__]);
    
    //only care about new jobs
    // might be other file edits which are ok to ignore...
    if(nil != [self findNewJob:file.destinationPath])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"found new cron job, so NOT IGNORING");
    
        //don't ignore
        shouldIgnore = NO;
    }
    
    //if ignoring
    // still update snapshot
    if(YES == shouldIgnore)
    {
        //update
        [self snapshot:file.destinationPath];
    }
    
    return shouldIgnore;
}

//get the name
// since it's a command, just return description
-(NSString*)itemName:(Event*)event
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"'%s' invoked", __PRETTY_FUNCTION__]);
    
    return self.description;
}

//already have object
// so just return it to caller
-(NSString*)itemObject:(Event*)event
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"'%s' invoked", __PRETTY_FUNCTION__]);
    
    //return latest job
    return [self findNewJob:event.file.destinationPath];
}

//'allow' event
// just update snapshot
-(void)allow:(Event *)event
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"'%s' invoked with %@", __PRETTY_FUNCTION__, event]);
    
    //just update snapshop
    [self snapshot:event.file.destinationPath];
    
    return;
}

//invoked when user clicks 'block'
// remove cron job from cron job file
-(BOOL)block:(Event*)event;
{
    //return var
    BOOL wasBlocked = NO;
    
    //jobs
    NSMutableArray* jobs = nil;

    //index of cron job to be blocked
    NSUInteger index = NSNotFound;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"'%s' invoked with %@", __PRETTY_FUNCTION__, event]);
    
    //get cron jobs
    jobs = [self loadJobs:event.file.destinationPath comments:YES];
    
    //find cron job that is to be blocked
    // reported crob job in 'itemBinary' of watch event
    index = [jobs indexOfObject:event.item.object];
    if(NSNotFound == index)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"could not find %@ in %@", event.item.object, event.file.destinationPath]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"index %lu", (unsigned long)index]);
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"cron jobs, before; %@", [jobs componentsJoinedByString:@"\n"]]);
    
    //remove unwanted cron job
    [jobs removeObjectAtIndex:index];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"cron jobs, after; %@", [jobs componentsJoinedByString:@"\n"]]);
    
    //update file
    [[jobs componentsJoinedByString:@"\n"] writeToFile:event.file.destinationPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"updated %@", event.file.destinationPath]);
    
    //happy
    wasBlocked = YES;
    
bail:
    
    //always update snapshot
    [self snapshot:event.file.destinationPath];
    
    return wasBlocked;
}

//load cron jobs
// parses each line into array
-(NSMutableArray*)loadJobs:(NSString*)path comments:(BOOL)comments
{
    //parsed jobs
    NSMutableArray* jobs = nil;
    
    //lines
    NSArray* lines = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"'%s' invoked", __PRETTY_FUNCTION__]);
    
    //alloc
    jobs = [NSMutableArray array];
    
    //convert data to string
    // and then split into lines
    lines = [[[NSString alloc] initWithData:[NSData dataWithContentsOfFile:path] encoding:NSUTF8StringEncoding] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    //add all jobs
    // possibly ignoring comments
    for(NSString* line in lines)
    {
        //skip blank line(s)
        if(0 == line.length) continue;
        
        //skip comments?
        if( (YES != comments) &&
            (YES == [line hasPrefix:@"#"]) )
        {
            //skip
            continue;
        }
        
        //save job
        [jobs addObject:line];
    }
    
    return jobs;
}

//finds latest crob job
// diff's snapshot w/ current ones
-(NSString*)findNewJob:(NSString*)path
{
    //new job
    NSString* newJob = nil;
    
    //current (+ new?) jobs
    NSMutableArray* jobs = nil;
    
    //new jobs
    NSArray* newJobs = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"'%s' invoked", __PRETTY_FUNCTION__]);
    
    //load (possibly) new cron jobs
    jobs = [self loadJobs:path comments:NO];
    if(nil == jobs) goto bail;

    //filter
    // returns all new jobs
    newJobs = [jobs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT SELF IN %@", self.snapshot[path]]];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"new jobs: %@", newJobs]);
    
    //grab first new one
    newJob = [newJobs firstObject];

bail:
    
    return newJob;
}

//update list of saved jobs
-(void)snapshot:(NSString*)path
{
    //user's cron jobs
    NSMutableArray* jobs = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"updating snapshot (crob jobs) from: %@", path]);
    
    //load
    jobs = [self loadJobs:path comments:NO];
    if(nil == jobs) goto bail;
    
    //update list
    self.snapshot[path] = jobs;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"cron job snapshot: %@", self.snapshot]);
    
bail:

    return;
}

@end
