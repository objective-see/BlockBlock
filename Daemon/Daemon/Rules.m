//
//  file: Rules.m
//  project: BlockBlock (launch daemon)
//  description: handles rules & actions such as add/delete
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"

#import "Rule.h"
#import "Rules.h"
#import "logging.h"
#import "utilities.h"
#import "Preferences.h"

/* format of rules
    dictionary of dictionaries
    key: signing id or process path (if unsigned)
    values: dictionary with:
        key: 'rules':
        value: array of rules
 
        key: 'csFlags':
        value: procs code signing flags
*/

//prefs obj
extern Preferences* preferences;

@implementation Rules

@synthesize rules;

//init method
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc rules dictionary
        rules = [NSMutableDictionary dictionary];
    }
    
    return self;
}

//load rules from disk
-(BOOL)load
{
    //result
    BOOL result = NO;
    
    //error
    NSError* error = nil;
    
    //rule's file
    NSString* rulesFile = nil;
    
    //archived rules
    NSData* archivedRules = nil;
    
    //init path to rule's file
    rulesFile = [INSTALL_DIRECTORY stringByAppendingPathComponent:RULES_FILE];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loading rules from: %@", rulesFile]);
    
    //no rules (yet)?
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:rulesFile])
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ not found, no rules yet?", rulesFile]);
        
        //no error though...
        result = YES;
        
        //bail
        goto bail;
    }
    
    //load archived rules from disk
    archivedRules = [NSData dataWithContentsOfFile:rulesFile];
    if(nil == archivedRules)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to load rules from: %@", RULES_FILE]);
        
        //bail
        goto bail;
    }
    
    //unarchive
    self. rules = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithArray: @[[NSMutableDictionary class], [NSMutableArray class], [NSString class], [NSNumber class], [Rule class]]]
                                                       fromData:archivedRules error:&error];
    if(nil == self.rules)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to unarchive rules from: %@ (%@)", RULES_FILE, error]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded %lu rules from: %@", (unsigned long)self.rules.count, RULES_FILE]);
    
    //happy
    result = YES;
    
bail:
    
    return result;
}

//add a rule
-(BOOL)add:(Event*)event
{
    //result
    BOOL added = NO;
    
    //rule
    Rule* rule = nil;
    
    //key
    NSString* key = nil;
 
    //log msg
    logMsg(LOG_DEBUG, @"adding rule");
    
    //existing rule?
    // can occur if multiple alerts & user approved (entire) process
    if(nil != (rule = [self find:event]))
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"rule (%@), would be duplicate for event (%@), so not adding", rule, event]);
        
        //happy
        added = YES;
        
        //bail
        goto bail;
    }
    
    //create rule
    rule = [[Rule alloc] init:event];
    
    //key
    // bundle ID or path
    key = (0 != event.file.process.signingID.length) ? event.file.process.signingID : event.file.process.path;
    if(NULL == key) goto bail;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"key for rule: %@", key]);
    
    //new process?
    if(nil == self.rules[key])
    {
        //init
        self.rules[key] = [NSMutableDictionary dictionary];
        
        //init (proc) rules
        self.rules[key][KEY_RULES] = [NSMutableArray array];
        
        //add cs flags
        self.rules[key][KEY_CS_FLAGS] = event.file.process.csFlags;
    }
    
    //(now) add rule
    [self.rules[key][KEY_RULES] addObject:rule];
    
    //save to disk
    if(YES != [self save])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to save rules");
        
        //bail
        goto bail;
    }
    
    //happy
    added = YES;
    
bail:
    
    return added;
}

//find (matching) rule
-(Rule*)find:(Event*)event
{
    //matching rule
    Rule* matchingRule = nil;
    
    //key
    NSString* key = nil;
    
    //sync to access
    @synchronized(self.rules)
    {
        //key
        // bundle ID or path
        key = (0 != event.file.process.signingID.length) ? event.file.process.signingID : event.file.process.path;
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"key for rule: %@", key]);
        
        //no match on process
        if(nil == self.rules[key])
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ didn't match any rules", key]);
            
            //bail
            goto bail;
        }
        
        //check all (process's) rules
        // same startup item and same path
        // note: * is a wildcard, meaning any match
        for(Rule* rule in self.rules[key][KEY_RULES])
        {
            //rule has signing id?
            //  make sure if was valid, still is
            if(0 != rule.processSigningID.length)
            {
                //(still) valid?
                if( (CS_VALID & rule.processCSFlags.unsignedIntegerValue) &&
                    !(CS_VALID & event.file.process.csFlags.unsignedIntegerValue) )
                {
                    //err msg
                    logMsg(LOG_ERR, [NSString stringWithFormat:@"%@ is not longer validly signed (csflags: %#lx -> %#lx", key, (unsigned long)rule.processCSFlags.unsignedIntegerValue, event.file.process.csFlags.unsignedIntegerValue]);
                    
                    //bail here
                    goto bail;
                }
            }
            
            //path mismatch?
            if( (YES != [rule.itemFile isEqualToString:@"*"]) &&
                (YES != [rule.itemFile isEqualToString:event.file.destinationPath]) )
            {
                //next
                continue;
            }
            
            //item mismatch
            if( (YES != [rule.itemObject isEqualToString:@"*"]) &&
                (YES != [rule.itemObject isEqualToString:event.item.object]) )
            {
                //next
                continue;
            }
            
            //got a match!
            matchingRule = rule;
            
            //done
            break;
        }
    }
        
bail:
    
    return matchingRule;
}

//delete rule
-(BOOL)delete:(Rule*)rule
{
    //result
    BOOL result = NO;
    
    //key
    NSString* key = nil;
    
    //(process) rules

    //rule index
    __block NSUInteger ruleIndex = -1;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"deleting rule, %@", rule]);
    
    //sync to access
    @synchronized(self.rules)
    {
        //key
        // bundle ID or path
        key = (0 != rule.processSigningID.length) ? rule.processSigningID : rule.processPath;
        
        //remove matching rule
        [self.rules[key][KEY_RULES] enumerateObjectsUsingBlock:^(Rule* currentRule, NSUInteger index, BOOL* stop)
        {
            //is match?
            if( (YES == [currentRule.itemFile isEqualToString:rule.itemFile]) &&
                 ( ((nil == currentRule.itemObject) && (nil == rule.itemObject)) ||
                   (YES == [currentRule.itemObject isEqualToString:rule.itemObject]) ) )
            {
                //save index
                ruleIndex = index;
            
                //stop
                *stop = YES;
            }
        }];
        
        //not found!?
        if(-1 == ruleIndex)
        {
            //err msg
            logMsg(LOG_ERR, @"failed to find rule");
            
            //bail
            goto bail;
        }
        
        //remove
        if(-1 != ruleIndex)
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found rule at %lu", (unsigned long)ruleIndex]);
            
            //remove
            [self.rules[key][KEY_RULES] removeObjectAtIndex:ruleIndex];
            
            //last (process rule?)
            if(0 == ((NSMutableArray*)self.rules[key][KEY_RULES]).count)
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"rule was only one for process, so removing process entry");
                
                //remove process
                [self.rules removeObjectForKey:key];
            }
        }
        
        //save to disk
        if(YES != [self save])
        {
            //err msg
            logMsg(LOG_ERR, @"failed to save (updated) rules");
            
            //bail
            goto bail;
        }
    }
        
    //happy
    result = YES;
    
bail:
    
    return result;
}

//save to disk
-(BOOL)save
{
    //result
    BOOL result = NO;
    
    //error
    NSError* error = nil;
    
    //rule's file
    NSString* rulesFile = nil;
    
    //archived rules
    NSData* archivedRules = nil;
    
    //init path to rule's file
    rulesFile = [INSTALL_DIRECTORY stringByAppendingPathComponent:RULES_FILE];
    
    //archive rules
    archivedRules = [NSKeyedArchiver archivedDataWithRootObject:self.rules requiringSecureCoding:YES error:&error];
    if(nil == archivedRules)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to archive rules: %@", error]);
        
        //bail
        goto bail;
    }
    
    //write out
    if(YES != [archivedRules writeToFile:rulesFile atomically:YES])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to save archived rules to: %@", rulesFile]);
        
        //bail
        goto bail;
    }
    
    //happy
    result = YES;
    
bail:
    
    return result;
}

@end
