//
//  File.m
//  FileMonitor
//
//  Created by Patrick Wardle on 9/1/19.
//  Copyright © 2020 Objective-See. All rights reserved.
//

#import <libproc.h>
#import <bsm/libbsm.h>
#import <sys/sysctl.h>

#import "FileMonitor.h"
#import "utilities.h"

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
        
        //init audit token
        auditToken = [NSData dataWithBytes:&message->process->audit_token length:sizeof(audit_token_t)];
        
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
            
        //open
        case ES_EVENT_TYPE_AUTH_OPEN:
        case ES_EVENT_TYPE_NOTIFY_OPEN:
            
            //set path
            self.destinationPath = convertStringToken(&message->event.open.file->path);
            
            break;
            
        //clone
        case ES_EVENT_TYPE_AUTH_CLONE:
            
            //set source
            self.sourcePath = convertStringToken(&message->event.clone.source->path);
            
            //set destination
            self.destinationPath = [convertStringToken(&message->event.clone.target_dir->path) stringByAppendingPathComponent:convertStringToken(&message->event.clone.target_name)];
            
            break;
            
        //exchange data
        case ES_EVENT_TYPE_AUTH_EXCHANGEDATA:
            
            //set source
            self.sourcePath = convertStringToken(&message->event.exchangedata.file1->path);
            
            //set destination
            self.destinationPath = convertStringToken(&message->event.exchangedata.file2->path);
            
            break;
            
        //copy file
        case ES_EVENT_TYPE_AUTH_COPYFILE:
            
            //set source
            self.sourcePath = convertStringToken(&message->event.copyfile.source->path);
            
            //set destination
            self.destinationPath = [convertStringToken(&message->event.copyfile.target_dir->path) stringByAppendingPathComponent:convertStringToken(&message->event.copyfile.target_name)];
            
            break;
        

        //write
        case ES_EVENT_TYPE_NOTIFY_WRITE:
            
            //set destination
            self.destinationPath = convertStringToken(&message->event.write.target->path);
            
            break;
            
            //close
        case ES_EVENT_TYPE_NOTIFY_CLOSE:
            
            //set destination
            self.destinationPath = convertStringToken(&message->event.close.target->path);
            
            break;
            
        //link
        case ES_EVENT_TYPE_NOTIFY_LINK:
        
            //set source
            self.sourcePath = convertStringToken(&message->event.link.source->path);
            
            //set destination, via combining
            self.destinationPath = [convertStringToken(&message->event.link.target_dir->path) stringByAppendingPathComponent:convertStringToken(&message->event.link.target_filename)];
            
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
            
        //truncate
        case ES_EVENT_TYPE_AUTH_TRUNCATE:
            
            //set destination
            self.destinationPath = convertStringToken(&message->event.truncate.target->path);
            
            break;
            
        //unlink
        case ES_EVENT_TYPE_AUTH_UNLINK:
        case ES_EVENT_TYPE_NOTIFY_UNLINK:
            
            //set destination
            self.destinationPath = convertStringToken(&message->event.unlink.target->path);
            
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
            
        //open
        case ES_EVENT_TYPE_NOTIFY_OPEN:
            [description appendString:@"\"ES_EVENT_TYPE_NOTIFY_OPEN\","];
            break;
            
        //write
        case ES_EVENT_TYPE_NOTIFY_WRITE:
            [description appendString:@"\"ES_EVENT_TYPE_NOTIFY_WRITE\","];
            break;
            
        //close
        case ES_EVENT_TYPE_NOTIFY_CLOSE:
            [description appendString:@"\"ES_EVENT_TYPE_NOTIFY_CLOSE\","];
            break;
            
        //rename
        case ES_EVENT_TYPE_NOTIFY_RENAME:
            [description appendString:@"\"ES_EVENT_TYPE_NOTIFY_RENAME\","];
            break;
            
        //link
        case ES_EVENT_TYPE_NOTIFY_LINK:
            [description appendString:@"\"ES_EVENT_TYPE_NOTIFY_LINK\","];
            break;
            
        //unlink
        case ES_EVENT_TYPE_NOTIFY_UNLINK:
            [description appendString:@"\"ES_EVENT_TYPE_NOTIFY_UNLINK\","];
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
