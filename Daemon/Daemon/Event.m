//
//  WatchEvent.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/26/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//



#import "consts.h"
#import "logging.h"
#import "utilities.h"

#import "Item.h"
#import "Event.h"
#import "PluginBase.h"

#import "FileMonitor.h"

@implementation Event

@synthesize file;
@synthesize item;
@synthesize scope;
@synthesize action;

@synthesize uuid;
@synthesize plugin;
@synthesize timestamp;

//init
-(id)init:(File*)file plugin:(PluginBase*)plugin
{
    self = [super init];
    if(self)
    {
        //create a uuid
        uuid = [[NSUUID UUID] UUIDString];
        
        //create timestamp
        timestamp = [NSDate date];
        
        //save file
        self.file = file;
        
        //save plugin
        self.plugin = plugin;
        
        //init item
        // calls into plugin to set name, obj, etc...
        self.item = [[Item alloc] init:self];
    }
    
    return self;
}

//TODO: convert to coder! 
//create an (deliverable) dictionary object
-(NSMutableDictionary*)toAlert
{
    //event for alert
    NSMutableDictionary* alert = nil;
    
    //signing info
    NSMutableDictionary* signingInfo = nil;
    
    //alloc
    alert = [NSMutableDictionary dictionary];
    
    //alloc
    signingInfo = [NSMutableDictionary dictionary];
    
    //add uuid
    alert[ALERT_UUID] = self.uuid;
    
    // for top of alert window
    
    //add process name
    alert[ALERT_PROCESS_NAME] = valueForStringItem(self.file.process.name);
    
    //add alert msg
    alert[ALERT_MESSAGE] = self.plugin.alertMsg;
    
    //add pid
    alert[ALERT_PROCESS_ID] = [NSNumber numberWithUnsignedInt:self.file.process.pid];
    
    //add path
    alert[ALERT_PROCESS_PATH] = valueForStringItem(self.file.process.path);
    
    //add args
    if(0 != self.file.process.arguments.count)
    {
        //add
        alert[ALERT_PROCESS_ARGS] = self.file.process.arguments;
    }
    
    //add file (path) of startup item
    alert[ALERT_ITEM_FILE] = valueForStringItem(self.file.destinationPath);
    
    //add flag indicating its restricted (SIP'd)
    alert[ALERT_ITEM_FILE_RESTRICTED] = [NSNumber numberWithBool:isFileRestricted(file.destinationPath)];
    
    //add name of startup item
    alert[ALERT_ITEM_NAME] = valueForStringItem(self.item.name);

    //add startup object
    // this is either a binary, or a cmd
    alert[ALERT_ITEM_OBJECT] = valueForStringItem(self.item.object);
    
    //add timestamp
    alert[ALERT_TIMESTAMP] = self.file.timestamp.description;
    
    //add cs flags
    signingInfo[CS_FLAGS] = self.file.process.csFlags;
    
    //add platform binary
    signingInfo[PLATFORM_BINARY] = self.file.process.isPlatformBinary;
    
    //add team id
    if(nil != self.file.process.teamID)
    {
        //add
        signingInfo[TEAM_ID] = self.file.process.teamID;
    }
    
    //add signing id
    if(nil != self.file.process.signingID)
    {
        //add
        signingInfo[SIGNING_ID] = self.file.process.signingID;
    }
    
    //now add signing info
    alert[ALERT_PROCESS_SIGNING_INFO] = signingInfo;
    
    //init/add process ancestors
    // pid:name mapping for alert window
    alert[ALERT_PROCESS_ANCESTORS] = [self buildProcessHierarchy:self.file.process];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"sending alert to user (client): %@", alert]);
    
    return alert;
}

//determines if a event is related
// checks things like process path, plugins, paths, etc
-(BOOL)isRelated:(Event*)lastEvent
{
    //dbg msg
    logMsg(LOG_DEBUG, @"checking if event is related");
    
    //check 1:
    // different plugins mean unrelated watch events
    if(self.plugin != lastEvent.plugin)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"...plugin different");
        
        //nope!
        return NO;
    }
    
    //check #2
    // same (responsible) process path
    if(YES != [self.file.process.path isEqualToString:lastEvent.file.process.path])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"...process paths different");
        
        //nope!
        return NO;
    }
    
    //check #3
    // different startup path (i.e. plist)
    if(YES != [self.file.destinationPath isEqualToString:lastEvent.file.destinationPath])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"...startup paths different");
        
        //nope!
        return NO;
    }
    
    //check #4
    // different startup item
    if(YES != [self.item.object isEqualToString:lastEvent.item.object])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"...startup items different");
        
        //nope!
        return NO;
    }
    
    //check #5
    // 3 seconds between now last event means 'unrelated'
    if(3 <= [[NSDate date] timeIntervalSinceDate:lastEvent.timestamp])
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"...event happened more than 3 seconds ago (delta: %f)", [[NSDate date] timeIntervalSinceDate:lastEvent.timestamp]]);
        
        //nope!
        return NO;
    }
    
    //events appear to be related
    return YES;
}

//build an array of processes ancestry
// this is used to populate the 'ancesty' popup
-(NSMutableArray*)buildProcessHierarchy:(Process*)process
{
    //process hierarchy
    NSMutableArray* processHierarchy = nil;
    
    //ancestor
    NSNumber* ancestor = nil;
    
    //alloc
    processHierarchy = [NSMutableArray array];
    
    //add current process (leaf)
    // parent(s) will then be added at front...
    [processHierarchy addObject:[@{@"pid":[NSNumber numberWithInt:process.pid], @"name":valueForStringItem(process.name)} mutableCopy]];
    
    //get name and add each ancestor
    for(NSUInteger i=0; i<file.process.ancestors.count; i++)
    {
        //skip first one (self)
        // already have it (with pid/path!)
        if(0 == i) continue;
        
        //extact ancestor
        ancestor = file.process.ancestors[i];
        
        //add
        [processHierarchy addObject:[@{@"pid":ancestor, @"name":valueForStringItem(getProcessPath(ancestor.intValue))} mutableCopy]];
    }
        
    //add the index value
    // used to populate outline/table
    for(NSUInteger i = 0; i < processHierarchy.count; i++)
    {
        //set index
        processHierarchy[i][@"index"] = [NSNumber numberWithInteger:i];
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"process hierarchy: %@", processHierarchy]);

    return processHierarchy;
}

/*
//build an array of processes ancestry
// this is used to populate the 'ancesty' popup
-(NSMutableArray*)buildProcessHierarchy:(Process*)process
{
    //process hierarchy
    NSMutableArray* processHierarchy = nil;
    
    //ancestor
    NSNumber* ancestor = nil;
    
    //first try getting 'real' ancesty
    processHierarchy = generateProcessHierarchy(process.pid, process.name);
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"generated (real) process hierarchy: %@", processHierarchy]);

    //only got one?
    // ...check if `standard` ancestry has more
    if( (processHierarchy.count <= 1) &&
        (file.process.ancestors.count > 1) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"no parent found, will generate 'standard' process hierarchy"]);
        
        //get name and add each ancestor
        for(NSUInteger i=0; i<file.process.ancestors.count; i++)
        {
            //skip first one (self)
            // already have it (pid/path!)
            if(0 == i) continue;
            
            //extact ancestor
            ancestor = file.process.ancestors[i];
            
            //add
            [processHierarchy addObject:[@{@"pid":ancestor, @"name":valueForStringItem(getProcessPath(ancestor.intValue))} mutableCopy]];
        }
    }
        
    //add the index value
    // used to populate outline/table
    for(NSUInteger i = 0; i < processHierarchy.count; i++)
    {
        //set index
        processHierarchy[i][@"index"] = [NSNumber numberWithInteger:i];
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"final process hierarchy: %@", processHierarchy]);

    return processHierarchy;
}
 
*/

//for pretty print
-(NSString *)description {
    return [NSString stringWithFormat: @"process=%@, item file path=%@, timestamp=%@, item binary=%@", self.file.process, self.file.destinationPath, self.timestamp, self.item];
}

@end
