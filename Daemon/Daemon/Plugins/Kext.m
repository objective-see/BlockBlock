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
#import "Logging.h"
#import "Utilities.h"

#import <libkern/OSReturn.h>
#import <IOKit/kext/KextManager.h>

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
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"init'ing %@ (%p)", NSStringFromClass([self class]), self]);
        
        //set type
        self.type = PLUGIN_TYPE_KEXT;
    }

    return self;
}

//ignore StagedExtensions
// ...should pick up the initial event in /Extensions
-(BOOL)shouldIgnore:(File*)file
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
        logMsg(LOG_DEBUG, @"failed to find bundle/info dictionary for kext");
        
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
        logMsg(LOG_DEBUG, @"failed to find bundle/info dictionary for kext");
        
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
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"PLUGIN %@: blocking %@", NSStringFromClass([self class]), event.file.destinationPath]);
    
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
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got kext ID: %@", bundleID]);
           
        //unload
        status = KextManagerUnloadKextWithIdentifier((__bridge CFStringRef)(bundleID));
        if(noErr != status)
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to unload kext (%#x)", status]);
            
            //set flag
            blockingFailed = YES;
        }
        
        //unloaded ok
        // just log this fact...
        #ifdef DEBUG
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"successfully unloaded kext");
        }
        #endif
    }
    
    //failed to get bundle id
    // just log error, but don't bail
    else
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to resolve bundle ID for %@", event.file.destinationPath]);
        
        //set flag
        blockingFailed = YES;
    }
    
    //delete directory
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:event.file.destinationPath error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete %@ (%@)", event.file.destinationPath, error]);
        
        //set flag
        blockingFailed = YES;
    }
    
    //delete ok
    // just log this fact...
    #ifdef DEBUG
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"successfully removed kext's bundle");
    }
    #endif
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"kext was blocked, (fully? %d)", !blockingFailed]);
    
    return blockingFailed;
}

@end
