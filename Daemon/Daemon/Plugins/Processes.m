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
#import "Logging.h"
#import "Processes.h"
#import "utilities.h"

#import <EndpointSecurity/EndpointSecurity.h>

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
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"init'ing %@ (%p)", NSStringFromClass([self class]), self]);
        
        //set type
        self.type = PLUGIN_TYPE_PROCESS_MONITOR;
        
        //init scripts
        self.scripts = @[@"com.apple.sh", @"com.apple.bash", @"com.apple.ksh", @"com.apple.csh", @"com.apple.zsh", @"com.apple.dash", @"org.python.python", @"com.apple.perl", @"com.apple.ruby", @"com.apple.osascript"];
    }

    return self;
}

//should process be ignored?
// for now, yes, unless it's non-notarized translocated/quarantined (and not user approved)
-(BOOL)shouldIgnore:(Process*)process
{
    //flag
    BOOL ignore = YES;
    
    //flag
    // process (still) alive
    BOOL isAlive = NO;
    
    //flag
    // process is executing a script
    BOOL isScript = NO;
    
    //item path
    NSString* path = nil;
    
    //app bundle
    NSBundle* appBundle = nil;
    
    //app's path
    NSString* appPath = nil;
    
    //quarantine flags
    uint32_t quarantineFlags = QTN_NOT_QUARANTINED;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"checking if %@ should be allowed", process]);
    
    //init path from process
    path = process.path;
    
    //script?
    // item will be in argv[1]
    // so use that for the path to check
    if(YES == [self.scripts containsObject:process.signingID])
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ is a script interpreter...", process.name]);
        
        //has to have at least 2 args
        // process name, then path to script
        if(process.arguments.count < 2)
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ doesn't appear to have a script argument, will allow", process.name]);
            
            //done
            goto bail;
        }
        
        //extact 2nd arg
        // should be path to a script
        path = process.arguments[1];
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"extracted (potential) script: %@", path]);
        
        //sanity check
        // was argv[1] is a file?
        if(YES != [NSFileManager.defaultManager fileExistsAtPath:path])
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ doesn't appear to be a path, will allow %@", path, process.name]);
            
            //done
            goto bail;
        }
        
        //now set flag
        // process w/ script
        isScript = YES;
        
        //check if script event is the "same" as last
        // avoids situations where sh <script> forks bash <script>
        if(YES == [self isRelatedScriptEvent:process])
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ was run by %@, thus appears related, so will allow", path, lastScript.name]);
            
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
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ is platform binary || is notarized, will allow", process.name]);
        
        //done
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"using path: %@", path]);
    
    //not a script?
    // grab app bundle (for subsequent checks)
    if(YES != isScript)
    {
        //find app bundle
        appBundle = findAppBundle(path);
        if(nil != appBundle)
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"is app, with bundle...");
        }
    }
    
    //is an app store app?
    // ignore, as it's trusted (though not 'notarized' per se)
    if( (noErr == [process.signingInfo[KEY_SIGNATURE_STATUS] intValue]) &&
        (AppStore == [process.signingInfo[KEY_SIGNATURE_SIGNER] intValue]) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ is from the app store ...will allow", process.name]);
        
        //done
        goto bail;
    }

    //not translocated
    // ...if quarantined, make sure it's user approved
    if(YES != isTranslocated(path))
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ is not app translocated ...checking quarantine attributes", path]);
        
        //get quarantine flags
        quarantineFlags = getQuarantineFlags(path);
        
        //not quarantined?
        // ok, safe to allow
        if(QTN_NOT_QUARANTINED == quarantineFlags)
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ is not quarantined ...will allow", path]);
            
            //done
            goto bail;
        }
           
        //quarantined, but user is approved?
        // ok, safe to allow
        if(QTN_FLAG_USER_APPROVED & quarantineFlags)
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ is quarantined, but user approved ...will allow", path]);
            
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
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"app bundle, %@, is user approved ...will allow", appPath]);
            
            //done
            goto bail;
        }
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ is translocated or quarantined (and not user approved)", process.name]);
    
    //dbg
    logMsg(LOG_DEBUG, @"checking if process is still alive...");
    
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
        logMsg(LOG_DEBUG, @"processed died, so will ignore");
        
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
    if(YES == isScript)
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
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"checking if (script) process event is related: %@ vs %@", process, self.lastScript]);
    
    //sanity check
    // no last script
    if(nil == self.lastScript)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"no previous script event(s), thus obv. not related");
        
        //done
        goto bail;
    }
    
    //check path of script
    // new path -> not related
    if(YES != [process.arguments[1] isEqualToString:self.lastScript.arguments[1]])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"...script not the same, thus not related");
        
        //nope
        goto bail;
    }
    
    //was rpid of process
    // not last script's process -> not related
    if(process.rpid != self.lastScript.pid)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"responsible pid (%d) doesn't matches last script process (%d)", process.rpid, self.lastScript.pid]);
        
        //nope
        goto bail;
    }

    //dbg msg
    logMsg(LOG_DEBUG, @"script is the same, with no rpid match...appears related!");
    
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
    // then it's execing an translocated item
    if(YES == [self.scripts containsObject:event.process.signingID])
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

//for kext
// unload, then delete entire kext directory
-(BOOL)block:(Event*)event
{
    //flag
    BOOL blocked = NO;
    
    //block
    if(YES != (blocked = [self respond:event action:ES_AUTH_RESULT_DENY]))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to block %@", event.process.name]);
    }
    
bail:
    
    return blocked;
}

//allow
-(void)allow:(Event*)event
{
    //allow
    if(YES != [self respond:event action:ES_AUTH_RESULT_ALLOW])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to allow %@", event.process.name]);
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
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@: %@", (ES_AUTH_RESULT_ALLOW == action) ? @"allowing" : @"blocking", event.process.path]);
        
    //sync
    @synchronized(event)
    {
        //sanity check(s)
        if( (NULL == event.esfClient) ||
            (NULL == event.esfMessage) )
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"esf client/message was unset ...timeout hit?");
            
            //bail
            goto bail;
        }
            
        //take action
        result = es_respond_auth_result(event.esfClient, event.esfMessage, action, false);
        if(ES_RESPOND_RESULT_SUCCESS != result)
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"'es_respond_auth_result' failed with: %x", result]);
        }
        //success
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@: %@", (ES_AUTH_RESULT_ALLOW == action) ? @"allowed" : @"blocked", event.process.path]);
        }
        
        //free/unset message
        es_free_message(event.esfMessage);
        event.esfMessage = NULL;
        event.esfClient = NULL;
        
        //signal
        // as we've avoid the esf timeout
        dispatch_semaphore_signal(event.esfSemaphore);

    } //sync
    
    //happy
    responded = YES;
    
bail:
    
    return responded;
}

@end
