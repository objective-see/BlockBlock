//
//  file: XPCDaemon.m
//  project: BlockBlock (launch daemon)
//  description: interface for XPC methods, invoked by user
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Events.h"
#import "Event.h"

#import "Rule.h"
#import "Rules.h"
#import "consts.h"
#import "logging.h"
#import "XPCDaemon.h"
#import "utilities.h"
#import "Preferences.h"

/* GLOBALS */

//global rules obj
extern Rules* rules;

//global events obj
extern Events* events;

//global prefs obj
extern Preferences* preferences;

@implementation XPCDaemon

//load preferences and send them back to client
-(void)getPreferences:(void (^)(NSDictionary* preferences))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: '%s'", __PRETTY_FUNCTION__]);
    
    //reply
    reply(preferences.preferences);
    
    return;
}

//update preferences
-(void)updatePreferences:(NSDictionary *)updates
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: '%s' (%@)", __PRETTY_FUNCTION__, updates]);
    
    //update
    if(YES != [preferences update:updates])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to updates to preferences");
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
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: '%s'", __PRETTY_FUNCTION__]);
    
    //archive rules
    archivedRules = [NSKeyedArchiver archivedDataWithRootObject:rules.rules requiringSecureCoding:YES error:&error];
    if(nil == archivedRules)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to archive rules: %@", error]);
        
        //don't bail as still want to reply
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"archived %lu rules, and sending to user...", (unsigned long)rules.rules.count]);

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
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: '%s' (rule: %@)", __PRETTY_FUNCTION__, rule]);
    
    //remove row
    if(YES != [rules delete:rule])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete rule, %@", rule]);
        
        //don't bail as still want to reply
    }
    
    //archive (updated) rules
    archivedRules = [NSKeyedArchiver archivedDataWithRootObject:rules.rules requiringSecureCoding:YES error:&error];
    if(nil == archivedRules)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to archive rules: %@", error]);
        
        //don't bail as still want to reply
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"archived %lu rules, and sending to user...", (unsigned long)rules.rules.count]);

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
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: '%s'", __PRETTY_FUNCTION__]);

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
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"user says, 'block', so blocking %@", event]);
        
        //block
        [event.plugin block:event];
    }
    //allow
    else
    {
        //dbg/log msg
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"user says, 'allow', so allowing %@", event]);
        
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
            logMsg(LOG_ERR, @"failed to add rule");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"added/saved rule");
    }
    //temporary rule
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"user selected 'temporary' ...won't save rule");
    }

bail:
    
    return;
}

@end
