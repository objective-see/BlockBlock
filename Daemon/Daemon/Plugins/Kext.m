//
//  kext.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Kext.h"
#import "Item.h"
#import "Event.h"
#import "Consts.h"
#import "Utilities.h"

#import <libkern/OSReturn.h>
#import <IOKit/kext/KextManager.h>

/* GLOBALS */

//log handle
extern os_log_t logHandle;

// REGEX
// ^(\/System|)\/Library\/.+\.(?i)kext$
// breakdown:
// ^ -> starts with
// (\/System|) -> "/System" or nothing
// \/Library\/ -> "/Library/"
// .+\.(?i)kext$ -> <blah>.kext" (case insensitive)

@implementation Kext

//init
-(id)initWithParams:(NSDictionary*)watchItemInfo
{
    //init super
    self = [super initWithParams:watchItemInfo];
    if(nil != self)
    {
        //dbg msg
        os_log_debug(logHandle, "init'ing %{public}@ (%p)", NSStringFromClass([self class]), self);
        
        //set type
        self.type = PLUGIN_TYPE_KEXT;
    }

    return self;
}

//ignore StagedExtensions
// ...should pick up the initial event in /Extensions
-(BOOL)shouldIgnore:(File*)file message:(es_message_t *)message
{
    return [file.destinationPath containsString:@"/StagedExtensions/"];
}

//get the name of the kext
// load bundle and read 'CFBundleExecutable'
-(NSString*)itemName:(Event*)event
{
    //kext name
    NSString* name = nil;
    
    //kext bundle
    NSBundle* bundle = nil;
    
    //get bundle
    // will wait up to 1 second
    bundle = getBundle(event.file.destinationPath, 1.0f);
    if( (nil == bundle) ||
        (nil == bundle.infoDictionary) )
    {
        //dbg err msg
        os_log_debug(logHandle, "failed to find bundle/info dictionary for kext");
        
        //bail
        goto bail;
    }
    
    //extract name
    name = [bundle.infoDictionary[@"CFBundleExecutable"] lastPathComponent];
        
bail:
        
    return name;
}

//get the binary (path) of the kext
-(NSString*)itemObject:(Event*)event
{
    //kext name
    NSString* binary = nil;
    
    //kext bundle
    NSBundle* bundle = nil;
    
    //get bundle
    // will wait up to 1 second
    bundle = getBundle(event.file.destinationPath, 1.0f);
    if( (nil == bundle) ||
        (nil == bundle.infoDictionary) )
    {
        //dbg err msg
        os_log_debug(logHandle, "failed to find bundle/info dictionary for kext");
        
        //bail
        goto bail;
    }
    
    //extract
    binary = bundle.executablePath;

bail:
    
    return binary;
}

//for kext
// unload, then delete entire kext directory
-(BOOL)block:(Event*)event;
{
    //flag
    BOOL blockingFailed = NO;
    
    //error
    NSError* error = nil;
    
    //status from unloading kext
    OSReturn status = -1;
    
    //bundle
    NSBundle* bundle = nil;
    
    //bundle (kext) id
    NSString* bundleID = nil;
    
    //dbg msg
    os_log_debug(logHandle, "PLUGIN %{public}@: blocking %{public}@", NSStringFromClass([self class]), event.file.destinationPath);
    
    //load bundle
    // need bundle (kext) ID
    bundle = [NSBundle bundleWithPath:event.file.destinationPath];
    if( (nil != bundle) &&
        (nil != bundle.executablePath) )
    {
        //save it
        bundleID = bundle.bundleIdentifier;
    }
    
    //try unload kext
    if(nil != bundleID)
    {
        //dbg msg
        os_log_debug(logHandle, "got kext ID: %{public}@", bundleID);
           
        //unload
        status = KextManagerUnloadKextWithIdentifier((__bridge CFStringRef)(bundleID));
        if(noErr != status)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to unload kext (%#x)", status);
            
            //set flag
            blockingFailed = YES;
        }
        
        //unloaded ok
        // just log this fact...
        #ifdef DEBUG
        else
        {
            //dbg msg
            os_log_debug(logHandle, "successfully unloaded kext");
        }
        #endif
    }
    
    //failed to get bundle id
    // just log error, but don't bail
    else
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to resolve bundle ID for %{public}@", event.file.destinationPath);
        
        //set flag
        blockingFailed = YES;
    }
    
    //delete directory
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:event.file.destinationPath error:&error])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to delete %{public}@ (%{public}@)", event.file.destinationPath, error);
        
        //set flag
        blockingFailed = YES;
    }
    
    //delete ok
    // just log this fact...
    #ifdef DEBUG
    else
    {
        //dbg msg
        os_log_debug(logHandle, "successfully removed kext's bundle");
    }
    #endif
    
    //dbg msg
    os_log_debug(logHandle, "kext was blocked, (fully? %d)", !blockingFailed);
    
    return blockingFailed;
}

@end
