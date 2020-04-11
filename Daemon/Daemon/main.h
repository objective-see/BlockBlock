//
//  file: main.h
//  project: BlockBlock (daemon)
//  description: main (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Rules.h"
#import "Events.h"
#import "consts.h"
#import "logging.h"
#import "utilities.h"
#import "Preferences.h"
#import "XPCListener.h"

#ifndef main_h
#define main_h

//GLOBALS

//prefs obj
Preferences* preferences = nil;

//rules obj
Rules* rules = nil;

//alerts obj
Events* events = nil;

//XPC listener obj
XPCListener* xpcListener = nil;

//dispatch source for SIGTERM
dispatch_source_t dispatchSource = nil;

/* FUNCTIONS */

//check for full disk access
int fdaCheck(void);

//init a handler for SIGTERM
// can perform actions such as disabling firewall and closing logging
void register4Shutdown(void);

//daemon should only be unloaded if box is shutting down
// so handle things de-init logging, etc
void goodbye(void);

#endif /* main_h */
