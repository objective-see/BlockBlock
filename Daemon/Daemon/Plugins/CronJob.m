//
//  CronJob.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "CronJob.h"
#import "Logging.h"
#import "Utilities.h"
#import "WatchEvent.h"
#import "AppDelegate.h"
#import "ProcessMonitor.h"

@implementation CronJob

//init
-(id)initWithParams:(NSDictionary*)watchItemInfo
{
    //init super
    self = [super initWithParams:watchItemInfo];
    if(nil != self)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"init'ing %@ (%p)", NSStringFromClass([self class]), self]);
        #endif
        
        //set type
        self.type = PLUGIN_TYPE_CRON_JOB;
        
        //save original cron jobs
        // ->for all non-user paths (i.e. just root's)
        for(NSString* watchPath in self.watchPaths)
        {
            //skip user paths
            // ->handled when a new agent registers
            if(YES == [watchPath hasSuffix:@"~"])
            {
                //skip
                continue;
            }
            
            //update
            [self updateOriginals:watchPath];
        }
    }

    return self;
}

//take a closer look to make sure watch event is really one we care about
// ->for cron jobs the creation/modification/rename of crontab files
-(BOOL)shouldIgnore:(WatchEvent*)watchEvent
{
    //flag
    // ->default to ignore
    BOOL shouldIgnore = YES;
    
    //original cron jobs
    NSArray* originalCronJobs = nil;
    
    //possibly new cron jobs
    NSArray* newCronJobs = nil;
    
    //new cron job
    NSString* newCronJob = nil;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"CRON JOB %@ flag: %lu' set", watchEvent.path, (unsigned long)watchEvent.flags]);
    #endif
    
    //create/modification/rename of file
    // ->note: OS does a rename
    if( (FSE_CREATE_FILE == watchEvent.flags) ||
        (FSE_RENAME == watchEvent.flags) ||
        (FSE_CONTENT_MODIFIED == watchEvent.flags) )
    {
        //dbg msg
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ has 'FSE_CREATE_FILE/FSE_RENAME/FSE_CONTENT_MODIFIED (%lu)' set (not maybe ignoring)", watchEvent.path, (unsigned long)watchEvent.flags]);
        
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"current cron jobs: %@", [((AppDelegate*)[[NSApplication sharedApplication] delegate]).orginals objectForKey:watchEvent.path]]);
        
        //grab original crob jobs
        // ->parse into array
        originalCronJobs = [self parseCronJobs:[((AppDelegate*)[[NSApplication sharedApplication] delegate]).orginals objectForKey:watchEvent.path] includeComments:NO];
        
        //dbg msg
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"original jobs: %@", originalCronJobs]);
        
        //load new cron jobs
        // ->parse into array
        newCronJobs = [self parseCronJobs: [NSData dataWithContentsOfFile:watchEvent.path] includeComments:NO];
        
        //dbg msg
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"new jobs: %@", newCronJobs]);
        
        //find new job
        newCronJob = [self findNewJob:originalCronJobs newJobs:newCronJobs];
        
        //new cron job?
        if(nil != newCronJob)
        {
            //dbg msg
            //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ is a new cron job so NOT ignoring....", newCronJob]);
            
            //don't ignore
            shouldIgnore = NO;
            
            //set the command in the watch event
            // ->done here since we just parsed all the cron jobs etc.
            watchEvent.itemObject = newCronJob;
        }
        /*
        else
        {
            logMsg(LOG_DEBUG, @"no new cron job so NOT ignoring....");
        }
        */
    }
    /*
    //dbg
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%lu is a flag the %@ plugin doesn't care about....", (unsigned long)watchEvent.flags, NSStringFromClass([self class])]);
    }
    */
    
    //if ignoring
    // ->still update originals
    if(YES == shouldIgnore)
    {
        //update
        [self updateOriginals:watchEvent.path];
    }
    
    return shouldIgnore;
}

//invoked when user clicks 'allow'
// ->just update originals
-(void)allow:(WatchEvent *)watchEvent
{
    //just update originals
    [self updateOriginals:watchEvent.path];
    
    return;
}

//update original cron jobs for user
-(void)newAgent:(NSDictionary*)newUser
{
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"CRON JOBS, handling new agent %@/%@", newUser, self.watchPaths]);
    #endif
    
    //iterate over plugin's watch paths
    // ->any that are user specific (~) save original cron jobs for new user
    for(NSString* watchPath in self.watchPaths)
    {
        //save user specific (~) originals
        if(YES == [watchPath hasSuffix:@"~"])
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"CRON JOBS, saving orginals for %@", watchPath]);
            #endif
            
            //matched
            // ->save orginals
            [self updateOriginals:[watchPath stringByReplacingCharactersInRange:NSMakeRange(watchPath.length-1, 1) withString:newUser[KEY_USER_NAME]]];
        }
    }
    
    return;
}

//update originals
// ->ensures there is always the latest version of the ok/approved cron jobs saved
-(void)updateOriginals:(NSString*)path
{
    //user's cron jobs
    NSData* cronJobs = nil;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"updating orginals of user's cron jobs at: %@", path]);
    #endif
    
    //load login items
    cronJobs = [NSData dataWithContentsOfFile:path];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"user's originals: %@", [[NSString alloc] initWithData:cronJobs encoding:NSUTF8StringEncoding]]);
    #endif

    //save em
    if(nil != cronJobs)
    {
        //load into originals
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]).orginals setObject:cronJobs forKey:path];
    }

    return;
}

//parse cron jobs
// ->but each into an array
-(NSMutableArray*)parseCronJobs:(NSData*)fileData includeComments:(BOOL)includeComments
{
    //parsed jobs
    NSMutableArray* cronJobs = nil;
    
    //lines
    NSArray* lines = nil;
    
    //alloc
    cronJobs = [NSMutableArray array];
    
    //convert data to string
    // ->and then split into lines
    lines = [[[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    //add all jobs
    // ->ignore any lines that begin w/ '#'
    for(NSString* line in lines)
    {
        //skip comments?
        if( (YES != includeComments) &&
            (YES == [line hasPrefix:@"#"]))
        {
            //skip
            continue;
        }
        
        //save job
        [cronJobs addObject:line];
    }
    
    return cronJobs;
}

//subtract original crob jobs from current
-(NSString*)findNewJob:(NSArray*)originalCronJobs newJobs:(NSArray*)newCronJobs
{
    //new job
    NSString* newJob = nil;
    
    //new jobs
    NSArray* relativeComplement = nil;
    
    //filter
    // ->returns all new jobs (that didn't exist before)
    relativeComplement = [newCronJobs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT SELF IN %@", originalCronJobs]];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"new jobs: %@", relativeComplement]);
    #endif
    
    //grab first new one
    //TODO: handle multiple cron jobs?
    newJob = [relativeComplement firstObject];
    
    return newJob;
}

//invoked when user clicks 'block'
// ->remove cron job from cron job file
-(BOOL)block:(WatchEvent*)watchEvent;
{
    //return var
    BOOL wasBlocked = NO;
    
    //existing cron jobs
    // ->will contain the one that should be blocked
    NSMutableArray* cronJobs = nil;
    
    //index of cron job to be blocked
    NSUInteger index = NSNotFound;
    
    //get cron jobs
    cronJobs = [self parseCronJobs: [NSData dataWithContentsOfFile:watchEvent.path] includeComments:YES];
    
    //find cron job that is to be blocked
    // ->reported crob job in 'itemBinary' of watch event
    index = [cronJobs indexOfObject:watchEvent.itemObject];
    
    //sanity check
    // ->make sure item was found
    if(NSNotFound == index)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"could not find %@ in %@", watchEvent.itemObject, watchEvent.path]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"CRON JOBS, found %@ at index %lu", watchEvent.itemObject, (unsigned long)index]);
    #endif
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"CRON JOBS, before %@", [cronJobs componentsJoinedByString:@"\n"]]);
    #endif
    
    //remove unwanted cron job
    [cronJobs removeObjectAtIndex:index];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"CRON JOBS, after; %@", [cronJobs componentsJoinedByString:@"\n"]]);
    #endif
    
    //update file
    [[cronJobs componentsJoinedByString:@"\n"] writeToFile:watchEvent.path atomically:YES];
    
    //happy
    wasBlocked = YES;
    
//bail
bail:
    
    //always update originals
    [self updateOriginals:watchEvent.path];
    
    return wasBlocked;
}

//invoked to get name of item
// ->since it's a command, just return a hard-coded category name
-(NSString*)startupItemName:(WatchEvent*)watchEvent
{
    return @"crob job";
}

//invoked to get binary of item
// ->just return command (binary doesn't make sense for cron jobs) that was prev. stored in watchEvent
-(NSString*)startupItemBinary:(WatchEvent*)watchEvent
{
    return watchEvent.itemObject;
}
@end
