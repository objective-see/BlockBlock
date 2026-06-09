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

//interpreter signing IDs (Apple platform binaries)
NSMutableSet* interpreters = nil;

//interpreter executable names
// used for ad-hoc / non-Apple signed interpreters (node, etc.) where signingID isn't reliable
NSMutableSet* interpreterNames = nil;

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
        
        //init w/ ad-hoc / non-Apple signed interpreters (matched by name)
        interpreterNames = [NSMutableSet setWithArray:@[
            @"node"
        ]];
    }

    return self;
}

//should process be ignored?
// scripts: handled independently via PREF_BLOCK_SCRIPTS_MODE
// binaries: handled via notarization mode (default + all)
-(BOOL)shouldIgnore:(Process*)process message:(es_message_t *)message {
    
    os_log_debug(logHandle, "'%s' invoked", __PRETTY_FUNCTION__);
    
    //running a script?
    // script check fires only on (block-scripts mode + downloaded);
    // otherwise fall through so the *interpreter* binary still gets notarization-checked
    if(process.script.length) {
        
        //user opted into blocking downloaded scripts?
        if([preferences.preferences[PREF_BLOCK_SCRIPTS_MODE] boolValue] &&
           isDownloaded(process.script)) {
            os_log_debug(logHandle, "%{public}@ is a downloaded script, so *will not* ignore", process.script);
            
            self.lastScript = process;
            return NO;
        }
        
        //script monitoring off, or script not downloaded
        // fall through to binary/notarization checks on the interpreter itself
        os_log_debug(logHandle, "%{public}@ running script: script check didn't fire, evaluating interpreter binary", process.name);
    }
    
    //binary checks (also apply to interpreter when script check didn't fire above)
    
    //platform binary?
    // always allow
    if(process.isPlatformBinary.boolValue) {
        os_log_debug(logHandle, "%{public}@ is a platform binary, will ignore", process.name);
        return YES;
    }
    
    //App Store?
    // always allow (same as "notarized")
    if(AppStore == [process.signingInfo[KEY_SIGNATURE_SIGNER] intValue]) {
        os_log_debug(logHandle, "%{public}@ is from App Store, so will ignore", process.name);
        return YES;
    }

    //Notarized?
    // allowed (in any mode)
    if([process.signingInfo[KEY_SIGNING_IS_NOTARIZED] boolValue]) {
        os_log_debug(logHandle, "%{public}@ is notarized, so will ignore", process.name);
        return YES;
    }
    
    //non-notarized binary

    //All-mode?
    // don't ignore non-notarized
    if([preferences.preferences[PREF_NOTARIZATION_ALL_MODE] boolValue]) {
        os_log_debug(logHandle, "%{public}@ is not notarized (and 'all' mode is set), so *will not* ignore", process.name);
        return NO;
    }
    
    //default mode: only alert if downloaded
    if(!isDownloaded(process.path)) {
        os_log_debug(logHandle, "%{public}@ is not downloaded (and 'all' mode is not set), so will ignore", process.name);
        return YES;
    }
    
    //downloaded + non-notarized binary
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
    
    //script the actual trigger?
    // (i.e. block-scripts mode on + script downloaded — not just "process happens to have a script")
    if( event.process.script.length &&
        [preferences.preferences[PREF_BLOCK_SCRIPTS_MODE] boolValue] &&
        isDownloaded(event.process.script) )
    {
        alert = @"is attempting to run a downloaded script";
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
    
    //name
    NSString* name = event.process.name;
    
    //block
    if(YES != (blocked = [self respond:event action:ES_AUTH_RESULT_DENY])) {
        
        os_log_error(logHandle, "ERROR: failed to block %{public}@, will try kill", name);
        
        //kill
        if(noErr != kill(event.process.pid, SIGKILL)){
            os_log_error(logHandle, "ERROR: failed to kill %{public}@", name);
        }
        else {
            os_log_debug(logHandle, "killed %{public}@", name);
        }
    }
    
bail:
    
    return blocked;
}

//allow
// invoke helper w/ ES_AUTH_RESULT_ALLOW
-(void)allow:(Event*)event
{
    //allow
    if(YES != [self respond:event action:ES_AUTH_RESULT_ALLOW]) {
        os_log_error(logHandle, "ERROR: failed to allow %{public}@", event.process.name);
    }
    
    //remove quarantine attributes
    // so we won't (re)prompt user
    if(event.process.path.length) {
        removeQuarantine(event.process.path);
    }
    if(event.process.script.length){
        removeQuarantine(event.process.script);
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
        // don't cache for interpreter+script events: the verdict applies to *this* script,
        // not the interpreter binary. caching would auto-apply to all future scripts.
        BOOL cache = (0 == event.process.script.length);
        result = es_respond_auth_result(event.esClient, event.esMessage, action, cache);
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
