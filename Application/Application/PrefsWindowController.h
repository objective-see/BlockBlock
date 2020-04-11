//
//  file: PrefsWindowController.h
//  project: BlockBlock (main app)
//  description: preferences window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;

#import "XPCDaemonClient.h"
#import "UpdateWindowController.h"

/* CONSTS */

//modes view
#define TOOLBAR_MODES 0

//update view
#define TOOLBAR_UPDATE 1

//to select, need string ID
#define TOOLBAR_MODES_ID @"mode"

@interface PrefsWindowController : NSWindowController <NSWindowDelegate>

/* PROPERTIES */

//preferences
@property(nonatomic, retain)NSDictionary* preferences;

//toolbar
@property (weak) IBOutlet NSToolbar *toolbar;

//rules prefs view
@property (weak) IBOutlet NSView *rulesView;

//modes view
@property (strong) IBOutlet NSView *modesView;

//update view
@property (weak) IBOutlet NSView *updateView;

//update button
@property (weak) IBOutlet NSButton *updateButton;

//update indicator (spinner)
@property (weak) IBOutlet NSProgressIndicator *updateIndicator;

//update label
@property (weak) IBOutlet NSTextField *updateLabel;

//update window controller
@property(nonatomic, retain)UpdateWindowController* updateWindowController;

/* METHODS */

//toolbar button handler
-(IBAction)toolbarButtonHandler:(id)sender;

//button handler for all preference buttons
-(IBAction)togglePreference:(id)sender;

@end
