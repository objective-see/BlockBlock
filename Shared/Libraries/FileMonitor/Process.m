//
//  Process.m
//  FileMonitor
//
//  Created by Patrick Wardle on 9/1/19.
//  Copyright © 2020 Objective-See. All rights reserved.
//

@import OSLog;

#import <dlfcn.h>
#import <libproc.h>
#import <bsm/libbsm.h>
#import <sys/sysctl.h>

#import "signing.h"
#import "utilities.h"
#import "FileMonitor.h"


//hash length
// from: cs_blobs.h
#define CS_CDHASH_LEN 20

/* GLOBALS */

//processes cache
extern NSCache* processesCache;

//responsbile pid
extern pid_t (*getRPID)(pid_t pid);

//log handle
extern os_log_t logHandle;

/* FUNCTIONS */

//helper function
// get parent of arbitrary process
pid_t getParentID(pid_t child);

@implementation Process

@synthesize pid;
@synthesize exit;
@synthesize path;
@synthesize ppid;
@synthesize event;
@synthesize script;
@synthesize ancestors;
@synthesize arguments;
@synthesize timestamp;
@synthesize auditToken;
@synthesize signingInfo;
@synthesize architecture;

//init
// flag controls code signing options
-(id)init:(es_message_t*)message csOption:(NSUInteger)csOption
{
    //string value
    // used for various conversions
    NSString* string = nil;
    
    //process from msg
    es_process_t* process = NULL;
    
    //inode
    NSNumber* inode = 0;
    
    //cached process
    Process* cachedProcess = nil;
    
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc array for args
        self.arguments = [NSMutableArray array];
        
        //alloc array for parents
        self.ancestors = [NSMutableArray array];
        
        //alloc dictionary for signing info
        self.signingInfo = [NSMutableDictionary dictionary];
        
        //init exit
        self.exit = -1;
        
        //init user id
        self.uid = -1;
        
        //init event
        self.event = -1;
        
        //set start time
        self.timestamp = [NSDate date];
        
        //set type
        self.event = message->event_type;
        
        //init
        self.script = NULL;
        
        //event specific logic
        
        // set type
        // extract (relevant) process object, etc
        switch (message->event_type) {
            
            //exec
            case ES_EVENT_TYPE_AUTH_EXEC:
            case ES_EVENT_TYPE_NOTIFY_EXEC:
                
                //set process (target)
                process = message->event.exec.target;
                
                //extract/format args
                [self extractArgs:&message->event];
                
                break;
                
            //fork
            case ES_EVENT_TYPE_NOTIFY_FORK:
                
                //set process (child)
                process = message->event.fork.child;
                
                break;
                
            //exit
            case ES_EVENT_TYPE_NOTIFY_EXIT:
                
                //set process
                process = message->process;
                
                //set exit code
                self.exit = message->event.exit.stat;
                
                break;
                
            //BTM add
            // see if we can use instigator
            case ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_ADD:
                
                if( (message->version >= 8) &&
                    (message->event.btm_launch_item_add->instigator_token) ) {
                        process = message->event.btm_launch_item_add->instigator;
                }
            
                if(!process) {
                    process = message->process;
                }
                
                break;
            
            //default
            default:
                
                //set process
                process = message->process;
                
                break;
        }
        
        //init audit token
        self.auditToken = [NSData dataWithBytes:&process->audit_token length:sizeof(audit_token_t)];
        
        //init pid
        self.pid = audit_token_to_pid(process->audit_token);
        
        //init ppid
        self.ppid = process->ppid;
        
        //init rpid
        if(message->version >= 4) 
        {
            self.rpid = audit_token_to_pid(process->responsible_audit_token);
        }
        
        //init uuid
        self.uid = audit_token_to_euid(process->audit_token);
        
        //add cs flags
        self.csFlags = [NSNumber numberWithUnsignedInt:process->codesigning_flags];
        
        //path
        self.path = convertStringToken(&process->executable->path);
        
        //now grab inode
        inode = [NSNumber numberWithUnsignedLong:[self inode]];
        
        //now attempt to find cached process
        // via inode, so will be same binary (though pid/args, etc will be different)
        cachedProcess = [processesCache objectForKey:inode];
        
        //(basic) sanity check
        // make sure cs flags still match
        if(YES != [self.csFlags isEqualTo:cachedProcess.csFlags])
        {
            //unset
            cachedProcess = nil;
            
            //remove
            [processesCache removeObjectForKey:inode];
        }
        
        //generate name
        if(nil == cachedProcess)
        {
            self.name = [self getName];
        }
        //from cache
        else
        {
            self.name = cachedProcess.name;
        }
        
        //cpu type
        if(nil == cachedProcess)
        {
            self.architecture = [self getArchitecture];
        }
        //from cache
        else
        {
            self.architecture = cachedProcess.architecture;
        }
    
        //add signing id
        if(nil == cachedProcess)
        {
            if(nil != (string = convertStringToken(&process->signing_id)))
            {
                //add
                self.signingID = string;
            }
        }
        //from cache
        else
        {
            self.signingID = cachedProcess.signingID;
        }
        
        //add team id
        if(nil == cachedProcess)
        {
            if(nil != (string = convertStringToken(&process->team_id)))
            {
                //add
                self.teamID = string;
            }
        }
        //from cache
        else
        {
            self.teamID = cachedProcess.teamID;
        }
        
        //add platform binary
        self.isPlatformBinary = [NSNumber numberWithBool:process->is_platform_binary];
        
        //save cd hash
        if(nil == cachedProcess)
        {
            self.cdHash = [NSData dataWithBytes:(const void *)process->cdhash length:sizeof(uint8_t)*CS_CDHASH_LEN];
        }
        //from cache
        else
        {
            self.cdHash = cachedProcess.cdHash;
        }
               
        //when specified
        // generate full code signing info
        if(csNone != csOption)
        {
            if(nil == cachedProcess)
            {
                //generate code signing info
                [self generateCSInfo:csOption];
            }
            //from cache
            else
            {
                self.signingInfo = cachedProcess.signingInfo;
            }
        }
        
        //script
        if(message->version >= 2)
        {
            //check event type
            if( (ES_EVENT_TYPE_AUTH_EXEC == message->event_type) ||
                (ES_EVENT_TYPE_NOTIFY_EXEC == message->event_type) )
            {
                //save
                if(NULL != message->event.exec.script)
                {
                    self.script = convertStringToken(&message->event.exec.script->path);
                }
            }
        }
    
        //enumerate ancestors
        [self enumerateAncestors];
        
        //add process to processes cache
        if( (nil == cachedProcess) &&
            (0 != inode.unsignedLongValue) )
        {
            //add
            [processesCache setObject:self forKey:inode];
        }
    }
    
    return self;
}

//get's process' path
// note: path must be set
-(unsigned long)inode
{
    //stat
    struct stat fileStat = {0};
    
    //inode
    unsigned long iNode = 0;
    
    //stat
    if(0 == stat(self.path.fileSystemRepresentation, &fileStat))
    {
        //save
        iNode = fileStat.st_ino;
    }
  
    return iNode;
}

//generate code signing info
// sets 'signingInfo' iVar
-(void)generateCSInfo:(NSUInteger)csOption
{
    //generate via helper function
    self.signingInfo = generateSigningInfo(self, csOption, kSecCSDefaultFlags);
    
    return;
}

//get process' name
// either via app bundle, or path
-(NSString*)getName
{
    //name
    NSString* name = nil;
    
    //app path
    NSString* appPath = nil;
    
    //app bundle
    NSBundle* appBundle = nil;
    
    //convert path to app path
    // generally, <blah.app>/Contents/MacOS/blah
    appPath = [[[self.path stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    if(YES != [appPath hasSuffix:@".app"])
    {
        //bail
        goto bail;
    }
    
    //try load bundle
    // and verify it's the 'right' bundle
    appBundle = [NSBundle bundleWithPath:appPath];
    if( (nil != appBundle) &&
        (YES == [appBundle.executablePath isEqualToString:self.path]) )
    {
        //grab name from app's bundle
        name = [appBundle infoDictionary][@"CFBundleDisplayName"];
    }
    
bail:
    
    //still nil?
    // just grab from path
    if(nil == name)
    {
        //from path
        name = [self.path lastPathComponent];
    }
    
    return name;
}

//get process' architecture
-(NSUInteger)getArchitecture
{
    //architecuture
    NSUInteger architecture = ArchUnknown;
    
    //type
    cpu_type_t type = -1;
    
    //size
    size_t size = 0;
    
    //mib
    int mib[CTL_MAXNAME] = {0};
    
    //length
    size_t length = CTL_MAXNAME;
    
    //proc info
    struct kinfo_proc procInfo = {0};
    
    //get mib for 'proc_cputype'
    if(noErr != sysctlnametomib("sysctl.proc_cputype", mib, &length))
    {
        //bail
        goto bail;
    }
    
    //add pid
    mib[length] = self.pid;
    
    //inc length
    length++;
    
    //init size
    size = sizeof(cpu_type_t);
    
    //get CPU type
    if(noErr != sysctl(mib, (u_int)length, &type, &size, 0, 0))
    {
        //bail
        goto bail;
    }
    
    //reversing Activity Monitor
    // if CPU type is CPU_TYPE_X86_64, Apple sets architecture to 'Intel'
    if(CPU_TYPE_X86_64 == type)
    {
        //intel
        architecture = ArchIntel;
        
        //done
        goto bail;
    }
    
    //reversing Activity Monitor
    // if CPU type is CPU_TYPE_ARM64, Apple checks proc's p_flags
    // if P_TRANSLATED is set, then they set architecture to 'Intel'
    if(CPU_TYPE_ARM64 == type)
    {
        //default to apple
        architecture = ArchAppleSilicon;
        
        //(re)init mib
        mib[0] = CTL_KERN;
        mib[1] = KERN_PROC;
        mib[2] = KERN_PROC_PID;
        mib[3] = pid;
        
        //(re)set length
        length = 4;
        
        //(re)set size
        size = sizeof(procInfo);
        
        //get proc info
        if(noErr != sysctl(mib, (u_int)length, &procInfo, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //'P_TRANSLATED' set?
        // set architecture to 'Intel'
        if(P_TRANSLATED == (P_TRANSLATED & procInfo.kp_proc.p_flag))
        {
            //intel
            architecture = ArchIntel;
        }
    }
    
bail:
    
    return architecture;
}

//extract/format args
-(void)extractArgs:(es_events_t *)event
{
    //number of args
    uint32_t count = 0;
    
    //argument
    NSString* argument = nil;
    
    //get # of args
    count = es_exec_arg_count(&event->exec);
    if(0 == count)
    {
        //bail
        goto bail;
    }
    
    //extract all args
    for(uint32_t i = 0; i < count; i++)
    {
        //current arg
        es_string_token_t currentArg = {0};
        
        //extract current arg
        currentArg = es_exec_arg(&event->exec, i);
        
        //convert argument
        argument = convertStringToken(&currentArg);
        if(nil != argument)
        {
            //append
            [self.arguments addObject:argument];
        }
    }
    
bail:
    
    return;
}

//generate list of ancestors
// note: if possible, built off responsible pid (vs. parent)
-(void)enumerateAncestors
{
    //current process id
    pid_t currentPID = -1;
    
    //parent pid
    pid_t parentPID = -1;

    //have rpid (from ESF)
    // init parent w/ that
    if(0 != self.rpid)
    {
        parentPID = self.rpid;
    }
    //no rpid
    // try lookup via private API
    else if(NULL != getRPID)
    {
        //get rpid
        parentPID = getRPID(pid);
    }
    
    //couldn't find/get rPID?
    // default back to using ppid
    if( (parentPID <= 0) ||
        (self.pid == parentPID) )
    {
        //use ppid
        parentPID = self.ppid;
    }
    
    //add parent
    [self.ancestors addObject:[NSNumber numberWithInt:parentPID]];
        
    //set current to parent
    currentPID = parentPID;
    
    //complete ancestry
    while(YES)
    {
        //for parent
        // first try via rPID
        if(NULL != getRPID)
        {
            //get rpid
            parentPID = getRPID(currentPID);
        }
        
        //couldn't find/get rPID?
        // default back to using standard method
        if( (parentPID <= 0) ||
            (currentPID == parentPID) )
        {
            //get parent pid
            parentPID = getParentID(currentPID);
        }
        
        //done?
        if( (parentPID <= 0) ||
            (currentPID == parentPID) )
        {
            //bail
            break;
        }
        
        //update
        currentPID = parentPID;
        
        //add
        [self.ancestors addObject:[NSNumber numberWithInt:parentPID]];
    }
    
    return;
}

//for pretty printing
// though we convert to JSON
-(NSString *)description
{
    //description
    NSMutableString* description = nil;
    
    //cd hash
    // requires formatting
    NSMutableString* cdHash = nil;

    //init output string
    description = [NSMutableString string];

    //start process
    [description appendString:@"\"process\":{"];
       
    //add pid, path, etc
    [description appendFormat: @"\"pid\":%d,\"name\":\"%@\",\"path\":\"%@\",\"uid\":%d,",self.pid, self.name, self.path, self.uid];
   
    //add cpu type
    switch(self.architecture)
    {
        //intel
        case ArchIntel:
            [description appendFormat: @"\"architecture\":\"Intel\","];
            break;
        
        //apple
        case ArchAppleSilicon:
            [description appendFormat: @"\"architecture\":\"Apple Silicon\","];
            break;

        //unknown
        default:
            [description appendString:@"\"architecture\":\"unknown\","];
            break;
    }
    
    //arguments
    if(0 != self.arguments.count)
    {
       //start list
       [description appendFormat:@"\"arguments\":["];
       
       //add all arguments
       for(NSString* argument in self.arguments)
       {
           //skip blank args
           if(0 == argument.length) continue;
           
           //add
           [description appendFormat:@"\"%@\",", [argument stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];
       }
       
       //remove last ','
       if(YES == [description hasSuffix:@","])
       {
           //remove
           [description deleteCharactersInRange:NSMakeRange([description length]-1, 1)];
       }
       
       //terminate list
       [description appendString:@"],"];
    }
    //no args
    else
    {
       //add empty list
       [description appendFormat:@"\"arguments\":[],"];
    }

    //add ppid
    [description appendFormat: @"\"ppid\":%d,", self.ppid];
    
    //add rpdi
    [description appendFormat: @"\"rpid\":%d,", self.rpid];

    //add ancestors
    [description appendFormat:@"\"ancestors\":["];

    //add each ancestor
    for(NSNumber* ancestor in self.ancestors)
    {
       //add
       [description appendFormat:@"%d,", ancestor.unsignedIntValue];
    }

    //remove last ','
    if(YES == [description hasSuffix:@","])
    {
       //remove
       [description deleteCharactersInRange:NSMakeRange([description length]-1, 1)];
    }

    //terminate list
    [description appendString:@"],"];

    //signing info (reported)
    [description appendString:@"\"signing info (reported)\":{"];
    
    //add cs flags, platform binary
    [description appendFormat: @"\"csFlags\":%d,\"platformBinary\":%d,", self.csFlags.intValue, self.isPlatformBinary.intValue];
    
    //add signing id
    if(0 == self.signingID.length)
    {
        //blank
        [description appendString:@"\"signingID\":\"\","];
    }
    //not blank
    else
    {
        //append
        [description appendFormat:@"\"signingID\":\"%@\",", self.signingID];
    }
    
    //add team id
    if(0 == self.teamID.length)
    {
        //blank
        [description appendString:@"\"teamID\":\"\","];
    }
    //not blank
    else
    {
        //append
        [description appendFormat:@"\"teamID\":\"%@\",", self.teamID];
    }
    
    //alloc string for cd hash
    cdHash = [NSMutableString string];
    
    //format cd hash
    [self.cdHash enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop)
    {
        //To print raw byte values as hex
        for (NSUInteger i = 0; i < byteRange.length; ++i) {
            [cdHash appendFormat:@"%02X", ((uint8_t*)bytes)[i]];
        }
    }];
    
    //add cs hash
    [description appendFormat:@"\"cdHash\":\"%@\"", cdHash];
    
    //terminate dictionary
    [description appendString:@"},"];

    //signing info
    [description appendString:@"\"signing info (computed)\":{"];

    //add all key/value pairs from signing info
    for(NSString* key in self.signingInfo)
    {
       //value
       id value = self.signingInfo[key];
       
       //handle `KEY_SIGNATURE_SIGNER`
       if(YES == [key isEqualToString:KEY_SIGNATURE_SIGNER])
       {
           //convert to pritable
           switch ([value intValue]) {
           
               //'None'
               case None:
                   [description appendFormat:@"\"%@\":\"%@\",", key, @"none"];
                   break;
                   
               //'Apple'
               case Apple:
                   [description appendFormat:@"\"%@\":\"%@\",", key, @"Apple"];
                   break;
               
               //'App Store'
               case AppStore:
                   [description appendFormat:@"\"%@\":\"%@\",", key, @"App Store"];
                   break;
                   
               //'Developer ID'
               case DevID:
                   [description appendFormat:@"\"%@\":\"%@\",", key, @"Developer ID"];
                   break;

               //'AdHoc'
               case AdHoc:
                  [description appendFormat:@"\"%@\":\"%@\",", key, @"AdHoc"];
                  break;
                   
               default:
                   break;
           }
       }
       
       //number?
       // add as is
       else if(YES == [value isKindOfClass:[NSNumber class]])
       {
           //add
           [description appendFormat:@"\"%@\":%@,", key, value];
       }
       //array
       else if(YES == [value isKindOfClass:[NSArray class]])
       {
           //start
           [description appendFormat:@"\"%@\":[", key];
           
           //add each item
           [value enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL * _Nonnull stop) {
               
               //add
               [description appendFormat:@"\"%@\"", obj];
               
               //add ','
               if(index != ((NSArray*)value).count-1)
               {
                   //add
                   [description appendString:@","];
               }
               
           }];
           
           //terminate
           [description appendString:@"],"];
       }
       //otherwise
       // just escape it
       else
       {
           //add
           [description appendFormat:@"\"%@\":\"%@\",", key, value];
       }
    }

    //remove last ','
    if(YES == [description hasSuffix:@","])
    {
      //remove
      [description deleteCharactersInRange:NSMakeRange([description length]-1, 1)];
    }

    //terminate dictionary
    [description appendString:@"}"];

    //exit event?
    // add exit code
    if(ES_EVENT_TYPE_NOTIFY_EXIT == self.event)
    {
       //add exit
       [description appendFormat:@",\"exit code\":%d", self.exit];
    }

    //terminate process
    [description appendString:@"}"];

    return description;
}

@end

//helper function
// get parent of arbitrary process
pid_t getParentID(pid_t child)
{
    //parent id
    pid_t parentID = -1;
    
    //kinfo_proc struct
    struct kinfo_proc processStruct = {0};
    
    //size
    size_t procBufferSize = 0;
    
    //mib
    const u_int mibLength = 4;
    
    //syscall result
    int sysctlResult = -1;
    
    //init buffer length
    procBufferSize = sizeof(processStruct);
    
    //init mib
    int mib[mibLength] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, child};
    
    //make syscall
    sysctlResult = sysctl(mib, mibLength, &processStruct, &procBufferSize, NULL, 0);
    
    //check if got ppid
    if( (noErr == sysctlResult) &&
        (0 != procBufferSize) )
    {
        //save ppid
        parentID = processStruct.kp_eproc.e_ppid;
    }
    
    return parentID;
}
