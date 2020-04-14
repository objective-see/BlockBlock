//
//  file: XPCDaemonProtocol.h
//  project: BlockBlock (shared)
//  description: methods exported by the daemon
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

@class Event;

@protocol XPCDaemonProtocol

//get preferences
-(void)getPreferences:(void (^)(NSDictionary*))reply;

//update preferences
-(void)updatePreferences:(NSDictionary*)preferences;

//get rules
-(void)getRules:(void (^)(NSData*))reply;

//delete rule
-(void)deleteRule:(Rule*)rule reply:(void (^)(NSData*))reply;

//respond to an alert
-(void)alertReply:(NSDictionary*)alert;

//add rule
//-(void)addRule:(NSString*)path action:(NSUInteger)action user:(NSUInteger)user;



@end
