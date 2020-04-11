//
//  file: AppDelegate.h
//  project: BlockBlock (config)
//  description: application main/delegate (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;

#import "Configure.h"
#import "HelperComms.h"
#import "AboutWindowController.h"
#import "ConfigureWindowController.h"

//block for install/uninstall
typedef void (^block)(NSNumber*);

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    
}

//main menu
@property (weak, nonatomic) IBOutlet NSMenu *mainMenu;

//daemom comms object
@property(nonatomic, retain) HelperComms* xpcComms;

//status msg
@property (nonatomic, weak) IBOutlet NSTextField *statusMsg;

//about window controller
@property(nonatomic, retain)AboutWindowController* aboutWindowController;

//configure window controller
@property(nonatomic, retain)ConfigureWindowController* configureWindowController;


/* METHODS */

@end
