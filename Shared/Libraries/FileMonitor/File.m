//
//  File.m
//  FileMonitor
//
//  Created by Patrick Wardle on 9/1/19.
//  Copyright © 2020 Objective-See. All rights reserved.
//

@import OSLog;

#import <libproc.h>
#import <bsm/libbsm.h>
#import <sys/sysctl.h>

#import "FileMonitor.h"
#import "utilities.h"

//log handle
extern os_log_t logHandle;

/* GLOBALS */

//processes cache
extern NSCache* processCache;

/* FUNCTIONS */

@implementation File

@synthesize process;
@synthesize timestamp;
@synthesize sourcePath;
@synthesize destinationPath;

//init
-(id)init:(es_message_t*)message csOption:(NSUInteger)csOption
{
    //process audit token
    NSData* auditToken = nil;
    
    //init super
    self = [super init];
    if(nil != self)
    {
        //set type
        self.event = message->event_type;
        
        //set timestamp
        self.timestamp = [NSDate date];
    
        //BTM add
        // the instigator is more important
        if(message->event_type == ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_ADD) {
            if( (message->version >= 8) &&
                (message->event.btm_launch_item_add->instigator_token) ) {
                auditToken = [NSData dataWithBytes:&message->event.btm_launch_item_add->instigator_token length:sizeof(audit_token_t)];
            }
        }
        
        //default to process in ES msg
        if(!auditToken) {
            auditToken = [NSData dataWithBytes:&message->process->audit_token length:sizeof(audit_token_t)];
        }
        
        //check cache for (same) process
        // not found? create process obj...
        self.process = [processCache objectForKey:auditToken];
        if(nil == self.process)
        {
            //create process
            self.process = [[Process alloc] init:message csOption:csOption];
        }
        
        //sanity check
        // process creation failed?
        if(nil == process)
        {
            //unset
            self = nil;
            
            //bail
            goto bail;
        }
        
        //add to cache
        [processCache setObject:process forKey:auditToken];
    
        //extract file path(s)
        // logic is specific to event
        [self extractPaths:message];
    }
    
bail:
    
    return self;
}

//extract source & destination path
// this requires event specific logic
-(void)extractPaths:(es_message_t*)message
{
    //event specific logic
    switch (message->event_type) {
            
        //create
        case ES_EVENT_TYPE_NOTIFY_CREATE:
        {
            //destination, for existing file
            if(ES_DESTINATION_TYPE_EXISTING_FILE == message->event.create.destination_type)
            {
                //set
                self.destinationPath = convertStringToken(&message->event.create.destination.existing_file->path);
            }
            //destination, for new path
            else
            {
                //set, via combining
                self.destinationPath = [convertStringToken(&message->event.create.destination.new_path.dir->path) stringByAppendingPathComponent:convertStringToken(&message->event.create.destination.new_path.filename)];
            }
            
            break;
        }
            
        
        //write
        case ES_EVENT_TYPE_NOTIFY_WRITE:
            
            //set destination
            self.destinationPath = convertStringToken(&message->event.write.target->path);
            
            break;
            
        
        //rename
        case ES_EVENT_TYPE_NOTIFY_RENAME:
            
            //set source
            self.sourcePath = convertStringToken(&message->event.rename.source->path);
            
            //destination, for existing file
            if(ES_DESTINATION_TYPE_EXISTING_FILE == message->event.rename.destination_type)
            {
                //set
                self.destinationPath = convertStringToken(&message->event.rename.destination.existing_file->path);
            }
            //destination, for new path
            else
            {
                //set, via combining
                self.destinationPath = [convertStringToken(&message->event.rename.destination.new_path.dir->path) stringByAppendingPathComponent:convertStringToken(&message->event.rename.destination.new_path.filename)];
            }
            
            break;
            
        default:
            break;
    }
    
    return;
}

//for pretty printing
// though we convert to JSON
-(NSString *)description
{
    //description
    NSMutableString* description = nil;

    //init output string
    description = [NSMutableString string];
    
    //start JSON
    [description appendString:@"{"];
    
    //add event
    [description appendString:@"\"event\":"];
    
    //add event
    switch(self.event)
    {
        //create
        case ES_EVENT_TYPE_NOTIFY_CREATE:
            [description appendString:@"\"ES_EVENT_TYPE_NOTIFY_CREATE\","];
            break;
            
        //write
        case ES_EVENT_TYPE_NOTIFY_WRITE:
            [description appendString:@"\"ES_EVENT_TYPE_NOTIFY_WRITE\","];
            break;
            
        //rename
        case ES_EVENT_TYPE_NOTIFY_RENAME:
            [description appendString:@"\"ES_EVENT_TYPE_NOTIFY_RENAME\","];
            break;
                        
        default:
            break;
    }
    
    //add timestamp
    [description appendFormat:@"\"timestamp\":\"%@\",", self.timestamp];
    
    //start file
    [description appendString:@"\"file\":{"];
    
    //src path
    // option, so check
    if(0 != self.sourcePath)
    {
        //add
        [description appendFormat: @"\"source\":\"%@\",", self.sourcePath];
    }
   
    //dest path
    [description appendFormat: @"\"destination\":\"%@\",", self.destinationPath];
    
    //add process
    [description appendFormat: @"%@", self.process];
    
    //terminate file
    [description appendString:@"}"];
    
    //terminate entire JSON
    [description appendString:@"}"];

    return description;
}

@end
