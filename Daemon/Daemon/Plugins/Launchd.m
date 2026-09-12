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
#import "Utilities.h"

#import <fcntl.h>
#import <sys/stat.h>

/* GLOBALS */

//log handle
extern os_log_t logHandle;

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
        os_log_debug(logHandle, "init'ing %{public}@ (%p)", NSStringFromClass([self class]), self);
    
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
        //otherwise, likely a string
        // just use as is (assume no args)
        else if(YES == [programArgs isKindOfClass:[NSString class]])
        {
            //assign
            itemBinary = (NSString*)programArgs;
        }
    }
    
    //no string from 'ProgramArguments'?
    // try to extract string from 'Program'
    if( (YES != [itemBinary isKindOfClass:[NSString class]]) ||
        (0 == itemBinary.length) )
    {
        itemBinary = getValueFromPlist(event.file.destinationPath, @"Program", YES, 1.0f);
        if(YES != [itemBinary isKindOfClass:[NSString class]])
        {
            //unset
            itemBinary = nil;
            
            //bail
            goto bail;
        }
    }

bail:
    
    return itemBinary;
}

//block launch item
// unload (which terminates its process), then delete plist
// note: we don't kill by (plist-specified, so attacker-controlled) path, as that could kill arbitrary processes
-(BOOL)block:(Event*)event;
{
    //flag
    BOOL blockingFailed = NO;
    
    //task results
    NSDictionary* results = nil;
    
    //plist
    NSString* propertyList = nil;
    
    //plist's directory (fd)
    int directoryFD = -1;
    
    //plist (fd)
    int plistFD = -1;
    
    //plist's directory (stat)
    struct stat directoryStat = {0};
    
    //plist contents
    NSDictionary* contents = nil;
    
    //launchd domain/label
    NSString* target = nil;
    
    //extract plist
    propertyList = event.file.destinationPath;
    
    //dbg msg
    os_log_debug(logHandle, "PLUGIN %{public}@: blocking %{public}@", NSStringFromClass([self class]), propertyList);
    
    //STEP 0: open plist's directory, refusing to follow symlinks in *any* path component
    // ...as the path is user-controlled (e.g. ~/Library/LaunchAgents) and could be swapped between alert & block
    // then hold the fd for the remaining steps, so the path can't be changed underneath us
    directoryFD = open(propertyList.stringByDeletingLastPathComponent.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_NOFOLLOW_ANY);
    if(-1 == directoryFD)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to open directory of %{public}@ (error: %d) ...symlink?", propertyList, errno);
        
        //set flag
        blockingFailed = YES;
        
        //bail
        goto bail;
    }
    
    //STEP 1: unload launch item (via launchctl)
    // read plist (via fd) to get label, and unload in the correct domain
    // note: don't pass the path to launchctl, as it would be subject to the same (symlink) race
    plistFD = openat(directoryFD, propertyList.lastPathComponent.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW);
    if(-1 != plistFD)
    {
        //read/parse
        contents = [NSPropertyListSerialization propertyListWithData:[[[NSFileHandle alloc] initWithFileDescriptor:plistFD closeOnDealloc:NO] readDataToEndOfFile] options:NSPropertyListImmutable format:nil error:nil];
        
        //close
        close(plistFD);
    }
    
    //label?
    if([contents[@"Label"] isKindOfClass:[NSString class]])
    {
        //launch daemon?
        // system domain
        if(YES == [propertyList containsString:@"/LaunchDaemons/"])
        {
            //init
            target = [NSString stringWithFormat:@"system/%@", contents[@"Label"]];
        }
        //launch agent
        // gui domain of the plist's owner (or console user for /Library/LaunchAgents)
        else
        {
            //init
            target = [NSString stringWithFormat:@"gui/%u/%@", ( (0 == fstat(directoryFD, &directoryStat)) && (0 != directoryStat.st_uid) ) ? directoryStat.st_uid : getConsoleUserID(), contents[@"Label"]];
        }
        
        //unload via 'launchctl'
        results = execTask(LAUNCHCTL, @[@"bootout", target], YES, NO);
        if( (nil == results[EXIT_CODE]) ||
            (noErr != [results[EXIT_CODE] intValue]) )
        {
            //err msg
            os_log_error(logHandle, "failed to unload %{public}@, error: %{public}@", target, results[EXIT_CODE]);
            
            //set flag
            blockingFailed = YES;
            
            //don't bail since still want to delete, etc
        }
        //dbg msg
        #ifdef DEBUG
        else
        {
            //dbg msg
            os_log_debug(logHandle, "unloaded %{public}@", target);
        }
        #endif
    }
    //no label
    else
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to read label from %{public}@, so cannot unload", propertyList);
        
        //set flag
        blockingFailed = YES;
    }
    
    //STEP 2: delete the launch item's plist
    // relative to the (held) directory fd
    if(0 != unlinkat(directoryFD, propertyList.lastPathComponent.fileSystemRepresentation, 0))
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to delete %{public}@ (error: %d)", propertyList, errno);
        
        //set flag
        blockingFailed = YES;
        
        //don't bail (nothing left to do, but fall through to cleanup)
    }
    //dbg msg
    #ifdef DEBUG
    else
    {
        //dbg msg
        os_log_debug(logHandle, "deleted %{public}@", propertyList);
    }
    #endif
    
bail:
    
    //close directory
    if(-1 != directoryFD)
    {
        //close
        close(directoryFD);
    }
    
    //dbg msg
    os_log_debug(logHandle, "launch item was blocked, (fully? %d)", !blockingFailed);

    return !blockingFailed;
}

@end
