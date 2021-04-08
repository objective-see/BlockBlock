//
//  file: AlertWindowController.h
//  project: BlockBlock (login item)
//  description: window controller for main firewall alert (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//
@import Cocoa;

//#import "procInfo.h"

#import "ParentsWindowController.h"
#import "VirusTotalViewController.h"
#import "SigningInfoViewController.h"

@interface AlertWindowController : NSWindowController <NSTouchBarProvider, NSTouchBarDelegate>

/* PROPERTIES */

//event
@property(nonatomic, retain)NSDictionary* alert;

//touch bar
@property(nonatomic, retain)NSTouchBar* touchBar;

/* TOP */

//process icon
@property (weak) IBOutlet NSImageView *processIcon;

//process name
@property (weak) IBOutlet NSTextField *processName;

//general alert message
@property (weak) IBOutlet NSTextField *alertMessage;

//signing info button
@property (weak) IBOutlet NSButton *signingInfoButton;

//signing info: popover
@property (strong) IBOutlet NSPopover *signingInfoPopover;


//virus total: button
@property (weak) IBOutlet NSButton *virusTotalButton;

//virus total: popover
@property (strong) IBOutlet NSPopover *virusTotalPopover;

//view controller for ancestry view/popover
@property (weak) IBOutlet ParentsWindowController *ancestryViewController;

//ancestry button
@property (weak) IBOutlet NSButton *ancestryButton;

//popover for ancestry
@property (strong) IBOutlet NSPopover *ancestryPopover;

//process ancestry
@property (nonatomic, retain)NSMutableArray* processHierarchy;

/* BOTTOM */

//process summary (name/pid)
@property (weak) IBOutlet NSTextField *processSummary;

//process args
@property (weak) IBOutlet NSTextField *processArgs;

//process path
@property (weak) IBOutlet NSTextField *processPath;

//startup item (i.e. plist)
@property (weak) IBOutlet NSTextField *startupItem;

//startup item label
@property (weak) IBOutlet NSTextField *startupItemLabel;

//startup file (full path)
@property (weak) IBOutlet NSTextField *startupFile;

//startup object label
@property (weak) IBOutlet NSTextField *startupObjectLabel;

//startup object (binary or cmd)
@property (weak) IBOutlet NSTextField *startupObject;

//ancestry view
@property (strong) IBOutlet NSView *ancestryView;

//outline view in ancestry popover
@property (weak) IBOutlet NSOutlineView *ancestryOutline;

//text cell for ancestry popover
@property (weak) IBOutlet NSTextFieldCell *ancestryTextCell;

//time stamp
@property (weak) IBOutlet NSTextField *timeStamp;

//action scope label
@property (weak) IBOutlet NSTextField *actionScopeLabel;

//action scope dropdown
@property (weak) IBOutlet NSPopUpButton *actionScope;

//block button
@property (weak) IBOutlet NSButton *blockButton;

//allow button
@property (weak) IBOutlet NSButton *allowButton;

//check box for temp rule
@property (weak) IBOutlet NSButton *tempRule;

/* METHODS */

//handler for VT button
-(IBAction)vtButtonHandler:(id)sender;

//handler for process ancestry button
-(IBAction)ancestryButtonHandler:(id)sender;

//handler for user's response to alert
-(IBAction)handleUserResponse:(id)sender;

@end
