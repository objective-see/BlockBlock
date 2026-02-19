//
//  file: PrefsWindowController.h
//  project: BlockBlock (main app)
//  description: preferences window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Update.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "PrefsWindowController.h"
#import "UpdateWindowController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//xpc daemon
extern XPCDaemonClient* xpcDaemonClient;

@implementation PrefsWindowController

@synthesize toolbar;
@synthesize modesView;
@synthesize rulesView;
@synthesize updateView;
@synthesize updateWindowController;

//init 'general' view
// add it, and make it selected
-(void)awakeFromNib
{
    //set title
    self.window.title = [NSString stringWithFormat:@"BlockBlock v%@", getAppVersion()];
    
    //get prefs
    self.preferences = [xpcDaemonClient getPreferences];
    
    //set rules prefs as default
    [self toolbarButtonHandler:nil];
    
    //set rules prefs as default
    [self.toolbar setSelectedItemIdentifier:TOOLBAR_MODES_ID];
    
    return;
}

//invoked when user clicks on toolbar
-(IBAction)toolbarButtonHandler:(id)sender
{
    NSView* view = nil;
    
    [self.containerView.subviews.lastObject removeFromSuperview];
    
    switch(((NSToolbarItem*)sender).tag)
    {
        case TOOLBAR_MODES:
            view = self.modesView;
            ((NSButton*)[view viewWithTag:BUTTON_PASSIVE_MODE]).state = [self.preferences[PREF_PASSIVE_MODE] boolValue];
            ((NSButton*)[view viewWithTag:BUTTON_NO_ICON_MODE]).state = [self.preferences[PREF_NO_ICON_MODE] boolValue];
            break;
            
        case TOOLBAR_PROTECTIONS:
            view = self.protectionsView;
            ((NSButton*)[view viewWithTag:BUTTON_NOTARIZATION_MODE]).state = [self.preferences[PREF_NOTARIZATION_MODE] boolValue];
            
            ((NSButton*)[view viewWithTag:BUTTON_NOTARIZATION_ALL_MODE]).state = [self.preferences[PREF_NOTARIZATION_ALL_MODE] boolValue];
            
            //disable child if parent is off
            if(((NSButton*)[view viewWithTag:BUTTON_NOTARIZATION_MODE]).state == NSControlStateValueOff) {
                ((NSButton*)[view viewWithTag:BUTTON_NOTARIZATION_ALL_MODE]).enabled = NO;
            }
            
            ((NSButton*)[view viewWithTag:BUTTON_CLICKFIX_MODE]).state = [self.preferences[PREF_CLICKFIX_MODE] boolValue];
            ((NSButton*)[view viewWithTag:BUTTON_CLICKFIX_HEURISTICS_MODE]).state = [self.preferences[PREF_CLICKFIX_HEURISTICS_MODE] boolValue];
            
            //disable child if parent is off
            if(((NSButton*)[view viewWithTag:BUTTON_CLICKFIX_MODE]).state == NSControlStateValueOff) {
                ((NSButton*)[view viewWithTag:BUTTON_CLICKFIX_HEURISTICS_MODE]).enabled = NO;
            }
            
            break;
            
        case TOOLBAR_UPDATE:
            view = self.updateView;
            ((NSButton*)[view viewWithTag:BUTTON_NO_UPDATE_MODE]).state = [self.preferences[PREF_NO_UPDATE_MODE] boolValue];
            break;
            
        default:
            goto bail;
    }
    
    //size to fill container
    view.frame = self.containerView.bounds;
    
    //size to fill container
    view.frame = self.containerView.bounds;
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    //add to container
    [self.containerView addSubview:view];
    
bail:
    return;
}

//invoked when user toggles button
// update preferences for that button
-(IBAction)togglePreference:(id)sender {
    
    //button tag
    NSInteger tag = ((NSButton*)sender).tag;
    
    //button state
    NSInteger state = ((NSButton*)sender).state;
    
    //preferences
    NSMutableDictionary* updatedPreferences = [NSMutableDictionary dictionary];
    
    //child
    NSButton* child = nil;
    
    //notarization mode
    // toggle 'all' state off/on
    if(tag == BUTTON_NOTARIZATION_MODE) {
    
        //get button
        child = (NSButton*)[self.protectionsView viewWithTag:BUTTON_NOTARIZATION_ALL_MODE];
    }
    
    //ClickFix mode
    // toggle 'heuristics' state off/on
    else if(tag == BUTTON_CLICKFIX_MODE) {
    
        //get button
        child = (NSButton*)[self.protectionsView viewWithTag:BUTTON_CLICKFIX_HEURISTICS_MODE];
    }
    
    //child logic
    if(child) {
        
        //clear if parent is off
        if(state == NSControlStateValueOff) {
            child.state = NSControlStateValueOff;
        }
        
        //match parent's state
        child.enabled = (state == NSControlStateValueOn);
    }
        
    //set appropriate preference
    switch(tag)
    {
        //passive mode
        case BUTTON_PASSIVE_MODE:
            updatedPreferences[PREF_PASSIVE_MODE] = @(state);
            break;
            
        //no icon mode
        case BUTTON_NO_ICON_MODE:
            updatedPreferences[PREF_NO_ICON_MODE] = @(state);
            break;
        
        //notarization mode
        // toggle off child too
        case BUTTON_NOTARIZATION_MODE:
            updatedPreferences[PREF_NOTARIZATION_MODE] = @(state);
            if(state == NSControlStateValueOff) {
                updatedPreferences[PREF_NOTARIZATION_ALL_MODE] = @(NSControlStateValueOff);
            }
            break;
            
        //notarization all mode
        case BUTTON_NOTARIZATION_ALL_MODE:
            updatedPreferences[PREF_NOTARIZATION_ALL_MODE] = @(state);
            break;
         
        //ClickFix mode
        case BUTTON_CLICKFIX_MODE:
            updatedPreferences[PREF_CLICKFIX_MODE] = @(state);
            if(state == NSControlStateValueOff) {
                updatedPreferences[PREF_CLICKFIX_HEURISTICS_MODE] = @(NSControlStateValueOff);
            }
            break;
            
        //ClickFix heuristics mode
        case BUTTON_CLICKFIX_HEURISTICS_MODE:
            updatedPreferences[PREF_CLICKFIX_HEURISTICS_MODE] = @(state);
            break;
            
        //no update mode
        case BUTTON_NO_UPDATE_MODE:
            updatedPreferences[PREF_NO_UPDATE_MODE] = @(state);
            break;
            
        default:
            break;
    }
    
    //send XPC msg to daemon to update prefs
    [xpcDaemonClient updatePreferences:updatedPreferences];

    //get latest prefs
    // note: this will include (all) prefs, which is what we want
    self.preferences = [xpcDaemonClient getPreferences];
    
    //tell anybody we've updated
    [NSNotificationCenter.defaultCenter postNotificationName:PREFERENCES_UPDATED_NOTIFICATION object:nil userInfo:self.preferences];
    
    //some prefs require immediate action
    
    //no icon mode
    // toggle icon
    if(BUTTON_NO_ICON_MODE == tag)
    {
        //toggle icon
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]) toggleIcon:self.preferences];
    }
    
    //toggle (status menu) icon
    else if(BUTTON_CLICKFIX_MODE == tag) {
        
        //on?
        // start
        if(NSControlStateValueOn == state) {
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) startClickFixMonitor:YES];
        }
        //off?
        // stop
        else{
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) stopClickFixMonitor];
        }
    }
    
    return;
}

//'view rules' button handler
// call helper method to show rule's window
-(IBAction)viewRules:(id)sender
{
    //call into app delegate to show app rules
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]) showRules:nil];
    
    return;
}

//'check for update' button handler
-(IBAction)check4Update:(id)sender
{
    //update obj
    Update* update = nil;
    
    //disable button
    self.updateButton.enabled = NO;
    
    //reset
    self.updateLabel.stringValue = @"";
    
    //show/start spinner
    [self.updateIndicator startAnimation:self];
    
    //init update obj
    update = [[Update alloc] init];
    
    //check for update
    // 'updateResponse newVersion:' method will be called when check is done
    [update checkForUpdate:^(NSUInteger result, NSString* newVersion) {
        
        //process response
        [self updateResponse:result newVersion:newVersion];
        
    }];
    
    return;
}

//process update response
// error, no update, update/new version
-(void)updateResponse:(NSInteger)result newVersion:(NSString*)newVersion
{
    //re-enable button
    self.updateButton.enabled = YES;
    
    //stop/hide spinner
    [self.updateIndicator stopAnimation:self];
    
    switch(result)
    {
        //error
        case -1:
            
            //set label
            self.updateLabel.stringValue = @"error: update check failed";
            
            break;
            
        //no updates
        case 0:
            
            //dbg msg
            os_log_debug(logHandle, "no updates available");
            
            //set label
            self.updateLabel.stringValue = [NSString stringWithFormat:@"Installed version (%@),\r\nis the latest.", getAppVersion()];
            
            break;
         
            
        //new version
        case 1:
            
            //dbg msg
            os_log_debug(logHandle, "a new version (%{public}@) is available", newVersion);
            
            //alloc update window
            updateWindowController = [[UpdateWindowController alloc] initWithWindowNibName:@"UpdateWindow"];
            
            //configure
            [self.updateWindowController configure:[NSString stringWithFormat:@"a new version (%@) is available!", newVersion] buttonTitle:@"Update"];
            
            //center window
            [[self.updateWindowController window] center];
            
            //show it
            [self.updateWindowController showWindow:self];
            
            //invoke function in background that will make window modal
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                //make modal
                makeModal(self.updateWindowController);
                
            });
            
            break;
    }
    
    
    return;
}

//on window close
// set activation policy
-(void)windowWillClose:(NSNotification *)notification
{
     //wait a bit, then set activation policy
     dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
     ^{
         //on main thread
         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
             
             //set activation policy
             [((AppDelegate*)[[NSApplication sharedApplication] delegate]) setActivationPolicy];
             
         });
     });
    
    return;
}

@end
