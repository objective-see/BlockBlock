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
#import "Preferences.h"

#import <EndpointSecurity/EndpointSecurity.h>

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//prefs obj
extern Preferences* preferences;

//interpreters
NSMutableSet* interpreters = nil;

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
        
        //init w/ some common platform interpreters
        interpreters = [NSMutableSet setWithArray:@[
            @"com.apple.zsh", @"com.apple.bash", @"com.apple.python", @"com.apple.python2", @"com.apple.python3", @"com.apple.pythonw", @"com.apple.osascript"
        ]];
    }

    return self;
}

//should process be ignored?
// checks notarization status, quarantined (and not user approved), etc.
-(BOOL)shouldIgnore:(Process*)process message:(es_message_t *)message {
    
    os_log_debug(logHandle, "'%s' invoked", __PRETTY_FUNCTION__);
    
    //platfrom binary?
    // downloaded script: not allowed
    // no script / local script: allowed
    // note: this is only time we have to check script
    if(process.isPlatformBinary.boolValue) {
       
        //downloaded script?
        if(isDownloaded(process.script)) {
            os_log_debug(logHandle, "%{public}@ is a downloaded script, so *will not* ignore", process.script);
            
            self.lastScript = process;
            return NO;
        }
        //no || no downloaded script
        else {
            os_log_debug(logHandle, "%{public}@ is platform binary (with no/no downloaded script), so will ignore", process.name);
            return YES;
        }
    }
    
    //now, we're dealing w/ non-platform binaries
    
    //App Store?
    // always allow (same same as "notarized")
    if(AppStore == [process.signingInfo[KEY_SIGNATURE_SIGNER] intValue]) {
        os_log_debug(logHandle, "%{public}@ is from App Store, so will ignore", process.name);
        return YES;
    }

    //now, not from app store
    
    //Notarized?
    // allowed (in any mode)
    if([process.signingInfo[KEY_SIGNING_IS_NOTARIZED] boolValue]) {
        os_log_debug(logHandle, "%{public}@ is notarized, so will ignore", process.name);
        return YES;
    }
    
    //now, not notarized program

    //All-mode?
    // don't ignore non-notarized
    if([preferences.preferences[PREF_NOTARIZATION_ALL_MODE] boolValue]) {
        os_log_debug(logHandle, "%{public}@ is not notarized (and 'all' mode is set), so *will not* ignore", process.name);
        return NO;
    }
    
    //now, not in 'all' mode

    //Normal mode?
    // allow if not downloaded
    if(!isDownloaded(process.path)) {
        os_log_debug(logHandle, "%{public}@ is not downloaded (and 'all' mode is not set), so will ignore", process.name);
        return YES;
    }
    
    //now, is downloaded

    //Downloaded
    // + non-notarized
    return NO;
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
        
        //signal
        // as we've avoided the es timeout
        dispatch_semaphore_signal(event.esSemaphore);
        
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
    
    } //sync
    
    //happy
    responded = YES;
    
bail:
    
    return responded;
}

@end
