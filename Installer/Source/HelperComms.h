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
-(BOOL)install;

//load/unload launch daemon
-(BOOL)toggleDaemon:(BOOL)shouldLoad;

//uninstall
// takes flag to indicate full/partial
-(BOOL)uninstall:(BOOL)full;

//cleanup
// remove self
-(BOOL)cleanup;

@end
