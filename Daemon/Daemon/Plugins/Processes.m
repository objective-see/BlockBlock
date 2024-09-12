//
//  Processes.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Item.h"
#import "Event.h"
#import "consts.h"
#import "Processes.h"
#import "utilities.h"

#import <EndpointSecurity/EndpointSecurity.h>

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation Processes

@synthesize lastScript;

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
        self.type = PLUGIN_TYPE_PROCESS_MONITOR;
    }

    return self;
}

//should process be ignored?
// for now, yes, unless it's non-notarized translocated/quarantined (and not user approved)
-(BOOL)shouldIgnore:(Process*)process message:(es_message_t *)message
{
    //flag
    BOOL ignore = YES;
    
    //flag
    // process (still) alive
    BOOL isAlive = NO;
    
    //item path
    NSString* path = nil;
    
    //app bundle
    NSBundle* appBundle = nil;
    
    //app's path
    NSString* appPath = nil;
    
    //quarantine flags
    uint32_t quarantineFlags = QTN_NOT_QUARANTINED;
    
    //dbg msg
    //os_log_debug(logHandle, "checking if %{public}@ should be allowed", process.path);
    
    //init path from process
    path = process.path;
    
    //script?
    if(nil != process.script)
    {
        //use script as path instead
        path = process.script;
        
        //check if script event is the "same" as last
        // avoids situations where sh <script> forks bash <script>
        if(YES == [self isRelatedScriptEvent:process])
        {
            //dbg msg
            os_log_debug(logHandle, "%{public}@ was run by %{public}@, thus appears related, so will allow", path, lastScript.name);
            
            //done
            goto bail;
        }
    }
    
    //not a script
    // ignore here if it's an apple or notarized processes
    else if( (YES == process.isPlatformBinary.boolValue) ||
             (YES == [process.signingInfo[KEY_SIGNING_IS_NOTARIZED] boolValue]) )
    {
        //dbg msg
        os_log_debug(logHandle, "%{public}@ is platform binary || is notarized, will allow", process.name);
        
        //done
        goto bail;
    }
    
    //not a script?
    // grab app bundle (for subsequent checks)
    if(nil != process.script)
    {
        //find app bundle
        appBundle = findAppBundle(path);
        if(nil != appBundle)
        {
            //dbg msg
            os_log_debug(logHandle, "is app, with bundle...");
        }
    }
    
    //is an app store app?
    // ignore, as it's trusted (though not 'notarized' per se)
    if( (noErr == [process.signingInfo[KEY_SIGNATURE_STATUS] intValue]) &&
        (AppStore == [process.signingInfo[KEY_SIGNATURE_SIGNER] intValue]) )
    {
        //dbg msg
        os_log_debug(logHandle, "%{public}@ is from the app store ...will allow", process.name);
        
        //done
        goto bail;
    }

    //not translocated
    // ...if quarantined, make sure it's user approved
    if(YES != isTranslocated(path))
    {
        //dbg msg
        os_log_debug(logHandle, "%{public}@ is not app translocated ...checking quarantine attributes", path);
        
        //get quarantine flags
        quarantineFlags = getQuarantineFlags(path);
        
        //not quarantined?
        // ok, safe to allow
        if(QTN_NOT_QUARANTINED == quarantineFlags)
        {
            //dbg msg
            os_log_debug(logHandle, "%{public}@ is not quarantined ...will allow", path);
            
            //done
            goto bail;
        }
           
        //quarantined, but user is approved?
        // ok, safe to allow
        if(QTN_FLAG_USER_APPROVED & quarantineFlags)
        {
            //dbg msg
            os_log_debug(logHandle, "%{public}@ is quarantined, but user approved ...will allow", path);
            
            //done
            goto bail;
        }
           
        //get app path
        appPath = appBundle.bundlePath;
        
        //also check app bundle
        // to see if it has been approved
        quarantineFlags = getQuarantineFlags(appPath);
        if( (QTN_NOT_QUARANTINED != quarantineFlags) &&
            (QTN_FLAG_USER_APPROVED & quarantineFlags) )
        {
            //dbg msg
            os_log_debug(logHandle, "app bundle, %{public}@, is user approved ...will allow", appPath);
            
            //done
            goto bail;
        }
    }
    
    //dbg msg
    os_log_debug(logHandle, "%{public}@ is translocated or quarantined (and not user approved)", process.name);
    
    //dbg
    os_log_debug(logHandle, "checking if process is still alive...");
    
    //when macOS kills a process
    // we still get an event, so handle this case
    for(int i=0; i<5; i++)
    {
        //is (still) alive?
        isAlive = isProcessAlive(process.pid);
        
        //dead?
        // done!
        if(YES != isAlive) break;
        
        //nap
        [NSThread sleepForTimeInterval:0.1];
    }
    
    //process killed?
    if(YES != isAlive)
    {
        //dbg
        os_log_debug(logHandle, "processed died, so will ignore");
        
        //bail
        goto bail;
    }
    
    //process is:
    // translocated/quarantine (and unapproved)
    // non-notarized
    // and is still alive
    ignore = NO;

bail:
    
    //script?
    // save it
    if(nil != process.script)
    {
        //save
        self.lastScript = process;
    }
    
    return ignore;
}

//check if script event is the "same"
// avoids situations where sh <script> forks bash <script>
-(BOOL)isRelatedScriptEvent:(Process*)process
{
    //flag
    BOOL isRelated = NO;
    
    //dbg msg
    os_log_debug(logHandle, "checking if (script) process event is related: %{public}@ vs %{public}@", process, self.lastScript);
    
    //sanity check
    // no last script
    if(nil == self.lastScript)
    {
        //dbg msg
        os_log_debug(logHandle, "no previous script event(s), thus obv. not related");
        
        //done
        goto bail;
    }
    
    //check path of script
    // new path -> not related
    if(YES != [process.arguments[1] isEqualToString:self.lastScript.arguments[1]])
    {
        //dbg msg
        os_log_debug(logHandle, "...script not the same, thus not related");
        
        //nope
        goto bail;
    }
    
    //was rpid of process
    // not last script's process -> not related
    if(process.rpid != self.lastScript.pid)
    {
        //dbg msg
        os_log_debug(logHandle, "responsible pid (%d) doesn't matches last script process (%d)", process.rpid, self.lastScript.pid);
        
        //nope
        goto bail;
    }

    //dbg msg
    os_log_debug(logHandle, "script is the same, with no rpid match...appears related!");
    
    //set flag
    isRelated = YES;

bail:
    
    return isRelated;
}

//(customize) alert message
-(NSString*)alertMessage:(Event*)event
{
    //alert msg
    NSString* alert = nil;
    
    //init to default
    alert = self.alertMsg;
    
    //script?
    // customize alert msg
    if(nil != event.process.script)
    {
        //customize
        alert = @"is attempting to run a non-notarized script";
    }
    
    return alert;
}

//get name
-(NSString*)itemName:(Event*)event
{
    //get/return name
    return getProcessName(event.process.path);
}

//get path
-(NSString*)itemObject:(Event*)event
{
    return event.process.path;
}

//block
// invoke helper w/ ES_AUTH_RESULT_DENY
-(BOOL)block:(Event*)event
{
    //flag
    BOOL blocked = NO;
    
    //block
    if(YES != (blocked = [self respond:event action:ES_AUTH_RESULT_DENY]))
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to block %{public}@", event.process.name);
    }
    
bail:
    
    return blocked;
}

//allow
// invoke helper w/ ES_AUTH_RESULT_ALLOW
-(void)allow:(Event*)event
{
    //allow
    if(YES != [self respond:event action:ES_AUTH_RESULT_ALLOW])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to allow %{public}@", event.process.name);
    }
    
    return;
}

//respond
// either allow/block
-(BOOL)respond:(Event*)event action:(es_auth_result_t)action
{
    //flag
    BOOL responded = NO;
    
    //result
    es_respond_result_t result = !ES_RESPOND_RESULT_SUCCESS;
    
    //dbg msg
    os_log_debug(logHandle, "%{public}@: %{public}@", (ES_AUTH_RESULT_ALLOW == action) ? @"allowing" : @"blocking", event.process.path);
        
    //sync
    @synchronized(event)
    {
        //sanity check(s)
        if( (NULL == event.esClient) ||
            (NULL == event.esMessage) )
        {
            //dbg msg
            os_log_debug(logHandle, "esf client/message was unset ...timeout hit?");
            
            //bail
            goto bail;
        }
            
        //take action
        result = es_respond_auth_result(event.esClient, event.esMessage, action, true);
        if(ES_RESPOND_RESULT_SUCCESS != result)
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'es_respond_auth_result' failed with: %x", result);
        }
        //success
        else
        {
            //dbg msg
            os_log_debug(logHandle, "%{public}@: %{public}@", (ES_AUTH_RESULT_ALLOW == action) ? @"allowed" : @"blocked", event.process.path);
        }
        
        //release message
        if(@available(macOS 11.0, *))
        {
            //release
            es_release_message(event.esMessage);
        }
        //free message
        else
        {
            //free
            es_free_message(event.esMessage);
        }
        
        //unset message
        event.esMessage = NULL;
        
        //unset client
        event.esClient = NULL;
        
        //signal
        // as we've avoid the es timeout
        dispatch_semaphore_signal(event.esSemaphore);

    } //sync
    
    //happy
    responded = YES;
    
bail:
    
    return responded;
}

@end
