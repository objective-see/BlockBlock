//
//  file: XPCUserProtocol
//  project: BlockBlock (shared)
//  description: protocol for talking to the user (header)
//
//  created by Patrick Wardle
//  copyright (c) 2020 Objective-See. All rights reserved.
//

@import Foundation;

@class Event;

@protocol XPCUserProtocol

//show an alert
-(void)alertShow:(NSDictionary*)alert;

//remove login item
-(void)removeLoginItem:(NSURL*)loginItem reply:(void (^)(NSNumber*))reply;

@end

