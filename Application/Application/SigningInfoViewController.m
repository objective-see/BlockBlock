//
//  file: SigningInfoViewController
//  project: BlockBlock (login item)
//  description: view controller for signing info popup (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "FileMonitor.h"

#import "utilities.h"
#import "SigningInfoViewController.h"

@implementation SigningInfoViewController

@synthesize alert;

//automatically invoked
// configure popover with signing info
-(void)popoverWillShow:(NSNotification *)notification;
{
    //signing info
    NSDictionary* signingInfo = nil;
    
    //flags
    uint32_t csFlags = 0;
    
    //summary
    NSMutableString* summary = nil;
    
    //alloc string for summary
    summary = [NSMutableString string];

    //extract signing info
    signingInfo = alert[ALERT_PROCESS_SIGNING_INFO];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"signing information for popup: %@", signingInfo]);
    
    //start summary with item name
    [summary appendString:alert[ALERT_PROCESS_NAME]];
    
    //extract flags
    csFlags = [signingInfo[CS_FLAGS] unsignedIntValue];
    
    //set cs flags
    ((NSTextField*)[self.view viewWithTag:CS_FLAGS_VIEW]).stringValue = [NSString stringWithFormat:@"%#x", [signingInfo[CS_FLAGS] unsignedIntValue]];
    
    //set platform binary
    ((NSTextField*)[self.view viewWithTag:PLATFORM_BINARY_VIEW]).stringValue = (YES == [signingInfo[CS_FLAGS] boolValue]) ? @"yes" : @"no";
    
    //set team id
    ((NSTextField*)[self.view viewWithTag:TEAM_ID_VIEW]).stringValue = (nil != signingInfo[TEAM_ID]) ? signingInfo[TEAM_ID] : @"n/a";
    
    //set signing id
    ((NSTextField*)[self.view viewWithTag:SIGNING_ID_VIEW]).stringValue = (nil != signingInfo[SIGNING_ID]) ? signingInfo[SIGNING_ID] : @"n/a";
    
    //unsigned?
    if(0 == csFlags)
    {
        //append to summary
        [summary appendFormat:@" is not signed"];
        
        //bail
        goto bail;
    }
    //adhoc?
    if(CS_ADHOC & csFlags)
    {
        //append to summary
        [summary appendFormat:@" is signed, but adhoc ('CS_ADHOC')"];
        
        //bail
        goto bail;
    }
    
    //validly signed?
    else if(CS_VALID & csFlags)
    {
        //append to summary
        [summary appendFormat:@" is validly signed"];
    
        //apple?
        if(YES == [signingInfo[PLATFORM_BINARY] boolValue])
        {
            //append
            [summary appendFormat:@" (by Apple proper)"];
        }
        //developer code
        else
        {
            //append
            [summary appendFormat:@" (by a Developer Identity, '!PLATFORM_BINARY')"];
        }
    
        //bail
        goto bail;
    }
    
    //append to summary
    [summary appendFormat:@" has a signing issue (flags: %#x)", csFlags];
    
bail:
    
    //update UI
    self.message.stringValue = summary;
    
    return;
}

@end
