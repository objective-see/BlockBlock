//
//  Preferences.m
//  Daemon
//
//  Created by Patrick Wardle on 2/22/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "consts.h"
#import "Monitor.h"
#import "Preferences.h"

/* GLOBALS */

//monitor obj
extern Monitor* monitor;

//log handle
extern os_log_t logHandle;

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
            os_log_error(logHandle, "ERROR: failed to loads preferences from %{public}@", PREFS_FILE);
            
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
    os_log_debug(logHandle, "loaded preferences: %{public}@", self.preferences);
    
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
    os_log_debug(logHandle, "updating preferences (%{public}@)", updates);
    
    //user setting state?
    if(nil != updates[PREF_IS_DISABLED])
    {
        //dbg msg
        os_log_debug(logHandle, "client toggling BlockBlock state: %{public}@", updates[PREF_IS_DISABLED]);
        
        //disable?
        if(YES == [updates[PREF_IS_DISABLED] boolValue])
        {
            //dbg msg
            // and log to file
            os_log(logHandle, "disabling BlockBlock");
            
            //stop
            [monitor stop];
        }
        
        //enable?
        else
        {
            //dbg msg
            // and log to file
            os_log(logHandle, "enabling BlockBlock");
            
            //start
            [monitor start];
        }
    }
    
    //passive mode toggled off?
    // was allowing everything (cached); now needs re-evaluation
    if( (nil != updates[PREF_PASSIVE_MODE]) &&
        (![updates[PREF_PASSIVE_MODE] boolValue]) )
    {
        os_log_debug(logHandle, "passive mode toggled off, so clearing (ES) cache");
        [monitor.processMonitor clearCache];
    }
    
    //notarization or block-scripts mode changed?
    // verdict for previously-cached processes may differ under new prefs
    if( (nil != updates[PREF_NOTARIZATION_MODE]) ||
        (nil != updates[PREF_NOTARIZATION_ALL_MODE]) ||
        (nil != updates[PREF_BLOCK_SCRIPTS_MODE]) )
    {
        os_log_debug(logHandle, "notarization/block-scripts mode changed, so clearing (ES) cache");
        [monitor.processMonitor clearCache];
    }

    //add in (new) prefs
    [self.preferences addEntriesFromDictionary:updates];
    
    //save
    if(YES != [self save])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to save preferences");
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
