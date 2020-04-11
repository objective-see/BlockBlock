//
//  file: AppDelegate.h
//  project: BlockBlock (login item)
//  description: app delegate for login item (header)
//
//  created by Patrick Wardle
//  copyright (c) 2020 Objective-See. All rights reserved.
//

@import Cocoa;

#import "StatusBarItem.h"
#import "XPCDaemonClient.h"
#import "PrefsWindowController.h"
#import "RulesWindowController.h"
#import "UpdateWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>


/* PROPERTIES */

//status bar menu
@property(strong) IBOutlet NSMenu* statusMenu;

//status bar menu controller
@property(nonatomic, retain)StatusBarItem* statusBarItemController;

//preferences window controller
@property(nonatomic, retain)PrefsWindowController* prefsWindowController;

//rules window controller
@property(nonatomic, retain)RulesWindowController* rulesWindowController;

//update window controller
@property(nonatomic, retain)UpdateWindowController* updateWindowController;

//xpc for daemon comms
@property(nonatomic, retain)XPCDaemonClient* xpcDaemonClient;

//(main) app observer
@property(nonatomic, retain)NSObject* appObserver;

//notifcation changed observer
@property(nonatomic, retain)id prefsChanged;

/* METHODS */

//set app foreground/background
// determined by the app's window count
-(void)setActivationPolicy;

//'rules' menu item handler
// alloc and show rules window
-(IBAction)showRules:(id)sender;

//'preferences' menu item handler
// alloc and show preferences window
-(IBAction)showPreferences:(id)sender;

//toggle (status) bar icon
-(void)toggleIcon:(NSDictionary*)preferences;


@end

