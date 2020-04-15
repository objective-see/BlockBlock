//
//  file: Configure.h
//  project: BlockBlock (config)
//  description: install/uninstall logic (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#ifndef BlockBlock_Configure_h
#define BlockBlock_Configure_h

#import "HelperComms.h"
#import <Foundation/Foundation.h>

@interface Configure : NSObject
{
    
}

/* PROPERTIES */

//helper installed & connected
@property(nonatomic) BOOL gotHelp;

//daemom comms object
@property(nonatomic, retain) HelperComms* xpcComms;

/* METHODS */

//determine if installed
-(BOOL)isInstalled;

//determine if installed version is a beta
-(BOOL)isBetaInstalled;

//load/unload lauch daemon
// calls into helper via XPC
-(BOOL)toggleDaemon:(BOOL)shouldLoad;

//check if daemon has FDA
-(BOOL)shouldRequestFDA;

//invokes appropriate install || uninstall logic
-(BOOL)configure:(NSInteger)parameter;

//install
-(BOOL)install;

//uninstall
-(BOOL)uninstall:(BOOL)full;

//remove helper (daemon)
-(BOOL)removeHelper;

@end

#endif
