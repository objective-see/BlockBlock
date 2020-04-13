//
//  Preferences.m
//  Daemon
//
//  Created by Patrick Wardle on 2/22/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "consts.h"
#import "logging.h"
#import "Monitor.h"
#import "Preferences.h"

/* GLOBALS */

//monitor obj
extern Monitor* monitor;

@implementation Preferences

@synthesize preferences;

//init
// loads prefs
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //load
        if(YES != [self load])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to loads preferences from %@", PREFS_FILE]);
            
            //unset
            self = nil;
            
            //bail
            goto bail;
        }
    }
    
bail:
    
    return self;
}

//load prefs from disk
-(BOOL)load
{
    //flag
    BOOL loaded = NO;
    
    //load
    preferences = [NSMutableDictionary dictionaryWithContentsOfFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE]];
    if(nil == self.preferences)
    {
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded preferences: %@", self.preferences]);
    
    //happy
    loaded = YES;
    
bail:
    
    return loaded;
}

//update prefs
// handles logic for specific prefs & then saves
-(BOOL)update:(NSDictionary*)updates
{
    //flag
    BOOL updated = NO;

    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"updating preferences (%@)", updates]);
    
    //user setting state?
    if(nil != updates[PREF_IS_DISABLED])
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"client toggling BlockBlock state: %@", updates[PREF_IS_DISABLED]]);
        
        //disable?
        if(YES == [updates[PREF_IS_DISABLED] boolValue])
        {
            //dbg msg
            // and log to file
            logMsg(LOG_DEBUG|LOG_TO_FILE, @"disabling BlockBlock");
            
            //stop
            [monitor stop];
        }
        
        //enable?
        else
        {
            //dbg msg
            // and log to file
            logMsg(LOG_DEBUG|LOG_TO_FILE, @"enabling BlockBlock");
            
            //start
            [monitor start];
        }
    }

    //add in (new) prefs
    [self.preferences addEntriesFromDictionary:updates];
    
    //save
    if(YES != [self save])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to save preferences");
        
        //bail
        goto bail;
    }
    
    //happy
    updated = YES;
    
bail:
    
    return updated;
}

//save to disk
-(BOOL)save
{
    //save
    return [self.preferences writeToFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE] atomically:YES];
}

@end
