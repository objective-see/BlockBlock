//
//  file: HelperComms.h
//  project: BlockBlock (config)
//  description: interface to talk to blessed installer (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

#import "XPCProtocol.h"


@interface HelperComms : NSObject

//remote deamon proxy object
@property(nonatomic, retain) id <XPCProtocol> daemon;

//xpc connection
@property (atomic, strong, readwrite) NSXPCConnection* xpcServiceConnection;

/* METHODS */

//install
-(void)install:(void (^)(NSNumber*))reply;

//load/unload launch daemon
-(void)toggleDaemon:(BOOL)shouldLoad reply:(void (^)(NSNumber*))reply;

//uninstall
// takes flag to indicate full/partial
-(void)uninstall:(BOOL)full reply:(void (^)(NSNumber*))reply;

//cleanup
// remove self
-(void)cleanup:(void (^)(NSNumber*))reply;

@end
