//
//  file: XPCDaemonClient.h
//  project: BlockBlock (shared)
//  description: talk to daemon via XPC (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Foundation;

#import "Rule.h"
#import "XPCDaemonProto.h"

@interface XPCDaemonClient : NSObject

//xpc connection to daemon
@property (atomic, strong, readwrite)NSXPCConnection* daemon;

//get rules
// note: synchronous
-(NSArray*)getRules;

//get preferences
// note: synchronous
-(NSDictionary*)getPreferences;

//update (save) preferences
-(void)updatePreferences:(NSDictionary*)preferences;

//delete rule
-(NSArray*)deleteRule:(Rule*)rule;

/*
//add rule
-(void)addRule:(NSString*)processPath action:(NSUInteger)action;

//update rule
-(void)updateRule:(NSString*)processPath action:(NSUInteger)action;



//import rules
-(BOOL)importRules:(NSString*)rulesFile;
*/

//respond to alert
-(void)alertReply:(NSDictionary*)alert;

@end
