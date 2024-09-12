//
//  file: XPCDaemon.m
//  project: BlockBlock (launch daemon)
//  description: interface for XPC methods, invoked by user
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Rule.h"
#import "Event.h"
#import "Rules.h"
#import "Events.h"
#import "consts.h"
#import "XPCDaemon.h"
#import "utilities.h"
#import "Preferences.h"

/* GLOBALS */

//global rules obj
extern Rules* rules;

//global events obj
extern Events* events;

//log handle
extern os_log_t logHandle;

//global prefs obj
extern Preferences* preferences;

@implementation XPCDaemon

//load preferences and send them back to client
-(void)getPreferences:(void (^)(NSDictionary* preferences))reply
{
    //dbg msg
    os_log_debug(logHandle, "XPC request: '%s'", __PRETTY_FUNCTION__);
    
    //reply
    reply(preferences.preferences);
    
    return;
}

//update preferences
-(void)updatePreferences:(NSDictionary *)updates
{
    //dbg msg
    os_log_debug(logHandle, "XPC request: '%s' (%{public}@)", __PRETTY_FUNCTION__, updates);
    
    //update
    if(YES != [preferences update:updates])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to updates to preferences");
    }
    
    return;
}

//get rules
-(void)getRules:(void (^)(NSData*))reply
{
    //archived rules
    NSData* archivedRules = nil;
    
    //error
    NSError* error = nil;
    
    //dbg msg
    os_log_debug(logHandle, "XPC request: '%s'", __PRETTY_FUNCTION__);
    
    //archive rules
    archivedRules = [NSKeyedArchiver archivedDataWithRootObject:rules.rules requiringSecureCoding:YES error:&error];
    if(nil == archivedRules)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to archive rules: %{public}@", error);
        
        //don't bail as still want to reply
    }
    
    //dbg msg
    os_log_debug(logHandle, "archived %lu rules, and sending to user...", (unsigned long)rules.rules.count);

    //return rules
    reply(archivedRules);
           
    return;
}

//delete rule
-(void)deleteRule:(Rule*)rule reply:(void (^)(NSData*))reply
{
    //archived rules
    NSData* archivedRules = nil;
    
    //error
    NSError* error = nil;
    
    //dbg msg
    os_log_debug(logHandle, "XPC request: '%s' (rule: %{public}@)", __PRETTY_FUNCTION__, rule);
    
    //remove row
    if(YES != [rules delete:rule])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to delete rule, %{public}@", rule);
        
        //don't bail as still want to reply
    }
    
    //archive (updated) rules
    archivedRules = [NSKeyedArchiver archivedDataWithRootObject:rules.rules requiringSecureCoding:YES error:&error];
    if(nil == archivedRules)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to archive rules: %{public}@", error);
        
        //don't bail as still want to reply
    }
    
    //dbg msg
    os_log_debug(logHandle, "archived %lu rules, and sending to user...", (unsigned long)rules.rules.count);

    //return rules
    reply(archivedRules);
    
bail:
    
    return;
}

//handle client response to alert
-(void)alertReply:(NSDictionary*)alert
{
    //event
    Event* event = nil;
    
    //dbg msg
    os_log_debug(logHandle, "XPC request: '%s'", __PRETTY_FUNCTION__);

    //grab reported event
    @synchronized(events.reportedEvents)
    {
        //extact (via uuid)
        event = events.reportedEvents[alert[ALERT_UUID]];
        if(nil == event) goto bail;
    }
    
    //remove from 'shown'
    [events removeShown:event];
    
    //extract/save action
    event.action = [alert[ALERT_ACTION] unsignedIntValue];
    
    //extract scope
    event.scope = [alert[ALERT_ACTION_SCOPE] integerValue];
    
    //block?
    if(BLOCK_EVENT == event.action)
    {
        //dbg/log msg
        os_log(logHandle, "user says, 'block', so blocking %{public}@", event);
        
        //block
        [event.plugin block:event];
    }
    //allow
    else
    {
        //dbg/log msg
        os_log(logHandle, "user says, 'allow', so allowing %{public}@", event);
        
        //allow
        [event.plugin allow:event];
    }
    
    //not temp?
    // save rule
    if(YES != [alert[ALERT_TEMPORARY] boolValue])
    {
        //update rules
        // type of rule is 'user'
        if(YES != [rules add:event])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to add rule");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        os_log_debug(logHandle, "added/saved rule");
    }
    //temporary rule
    else
    {
        //dbg msg
        os_log_debug(logHandle, "user selected 'temporary' ...won't save rule");
    }

bail:
    
    //free es message
    if(NULL != event.esMessage)
    {
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
        
        //unset
        event.esMessage = NULL;
    }
    
    return;
}

@end
