//
//  Launchd.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Item.h"
#import "Event.h"
#import "Launchd.h"
#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"

// REGEX
// ^(\/System|\/Users\/[^\/]+|)\/Library\/(LaunchDaemons|LaunchAgents)\/.+\.(?i)plist$
// breakdown:
// ^ -> starts with
// (\/System|\/Users\/[^\/]+|) -> "/System" or "/Users/<blah>" or nothing
// \/Library\/ -> "/Library/"
// (LaunchDaemons|LaunchAgents) -> "LaunchDaemons" or "LaunchAgents"
// \/.+\.(?i)plist -> "/<blah>.plist" (case insensitive)

@implementation Launchd

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
        self.type = PLUGIN_TYPE_LAUNCHD;
    }

    return self;
}

//(customize) alert message
// either launch agent, or launch daemon
-(NSString*)alertMessage:(Event*)event
{
    //alert msg
    NSString* alert = nil;
    
    //init to default
    alert = self.alertMsg;
    
    //launch agent?
    if(YES == [event.file.destinationPath containsString:@"/LaunchAgents/"])
    {
        //set
        alert = @"installed a launch agent";
    }
    //launch daemon
    else if(YES == [event.file.destinationPath containsString:@"/LaunchDaemons/"])
    {
        //set
        alert = @"installed a launch daemon";
    }
    
    return alert;
}

//get the name of the launch item
-(NSString*)itemName:(Event*)event
{
    //get launch item binary
    // then just last component
    return [[self itemObject:event] lastPathComponent];
}

//get the binary (path) of the launch item
-(NSString*)itemObject:(Event*)event
{
    //path to launch item binary
    NSString* itemBinary = nil;
    
    //value of 'ProgramArguments'
    // can either be array or string
    id programArgs = nil;
    
    //get program args
    // path is in args[0]
    programArgs = getValueFromPlist(event.file.destinationPath, @"ProgramArguments", YES, 1.0f);
    if(nil != programArgs)
    {
        //when its an array
        // first object is the item binary
        if(YES == [programArgs isKindOfClass:[NSArray class]])
        {
            //extract path to binary
            itemBinary = [(NSArray*)programArgs firstObject];
        }
        //otherwise, its likely a string
        // just use as is (assume no args)
        else if(YES == [programArgs isKindOfClass:[NSString class]])
        {
            //assign
            itemBinary = (NSString*)programArgs;
        }
    }
    //when 'ProgramArguments' fails
    // check for just 'Program' key and use that
    if(0 == itemBinary.length)
    {
        //get value for 'ProgramArguments'
        //(should always be) a string
        itemBinary = getValueFromPlist(event.file.destinationPath, @"Program", YES, 1.0f);
    }
    
    //sanity check
    if(0 == itemBinary.length)
    {
        //bail
        goto bail;
    }
    
    //sanity check
    if(YES != [itemBinary isKindOfClass:[NSString class]])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"launch item's binary path, %@, is not a string (but: %@)", itemBinary, itemBinary.className]);
        
        //unset
        itemBinary = nil;
        
        //bail
        goto bail;
    }
    
bail:
    
    return itemBinary;
}

//block launch item
// unload, then delete plist, and finally kill binary it references
-(BOOL)block:(Event*)event;
{
    //flag
    BOOL blockingFailed = NO;
    
    //task results
    NSDictionary* results = nil;
    
    //error
    NSError* error = nil;
        
    //plist
    NSString* propertyList = nil;
    
    //extract plist
    propertyList = event.file.destinationPath;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"PLUGIN %@: blocking %@", NSStringFromClass([self class]), propertyList]);


    //STEP 1: unload launch item (via launchctl)
    
    //unload via 'launchctl'
    results = execTask(LAUNCHCTL, @[@"unload", propertyList], YES, NO);
    if( (nil == results[EXIT_CODE]) ||
        (noErr != [results[EXIT_CODE] intValue]) )
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to unload %@, error: %@", propertyList, results[EXIT_CODE]]);
        
        //set flag
        blockingFailed = YES;
        
        //don't bail since still want to delete, etc
    }
    //dbg msg
    #ifdef DEBUG
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"unloaded %@", propertyList]);
    }
    #endif
    
    
    //STEP 2: delete the launch item's plist
    
    //delete
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:propertyList error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete %@ (%@)", propertyList, error]);
        
        //set flag
        blockingFailed = YES;
        
        //don't bail since still want to kill binary...
    }
    
    //dbg msg
    #ifdef DEBUG
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"deleted %@", propertyList]);
    }
    #endif
    
    
    //STEP 3: kill launch item process
    
    //find any/all processes
    for(NSNumber* pid in getProcessIDs(event.item.object, -1))
    {
        //kill
        if(noErr != kill(pid.intValue, SIGKILL))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to kill %@:%@ (error: %d)", pid, event.item.object, errno]);
            
            //set flag
            blockingFailed = YES;
        }
        //dbg msg
        #ifdef DEBUG
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"killed %@:%@", pid, event.item.object]);
        }
        #endif
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"launch item was blocked, (fully? %d)", !blockingFailed]);

    return blockingFailed;
}

@end
