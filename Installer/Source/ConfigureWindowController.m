//
//  file: ConfigureWindowController.m
//  project: BlockBlock (config)
//  description: install/uninstall window logic
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Configure.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "ConfigureWindowController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation ConfigureWindowController

@synthesize statusMsg;
@synthesize fdaMessage;
@synthesize configureObj;
@synthesize diskAccessView;
@synthesize moreInfoButton;
@synthesize fdaActivityIndicator;
@synthesize appActivationObserver;

//automatically called when nib is loaded
// just center window, alloc some objs, etc
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    //when supported
    // indicate title bar is transparent (too)
    if(YES == [self.window respondsToSelector:@selector(titlebarAppearsTransparent)])
    {
        //set transparency
        self.window.titlebarAppearsTransparent = YES;
    }
    
    //make first responder
    // calling this without a timeout sometimes fails :/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        
        //and make it first responder
        [self.window makeFirstResponder:self.installButton];
        
    });

    //init configure object
    if(nil == self.configureObj)
    {
        //alloc/init Config obj
        configureObj = [[Configure alloc] init];
    }
    
    return;
}

//configure window/buttons
// also brings window to front
-(void)configure
{
    //flag
    BOOL isInstalled = NO;
    
    //init flag
    isInstalled = [self.configureObj isInstalled];
    
    //set window title
    [self window].title = [NSString stringWithFormat:@"version %@", getAppVersion()];
    
    //init status msg
    [self.statusMsg setStringValue:@"Protection against persistent malware! 👾"];
    
    //uninstall via app?
    // just enable uinstall button
    if(YES == [NSProcessInfo.processInfo.arguments containsObject:CMD_UNINSTALL_VIA_UI])
    {
        //enable uninstall
        self.uninstallButton.enabled = YES;
        
        //disable install
        self.installButton.enabled = NO;
        
        //make uninstall button first responder
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            
            //set first responder
            [self.window makeFirstResponder:self.uninstallButton];
            
        });
        
    }
    
    //app already installed?
    // enable 'uninstall' button
    // change 'install' button to say 'upgrade'
    else if(YES == isInstalled)
    {
        //enable uninstall
        self.uninstallButton.enabled = YES;
        
        //set to upgrade
        self.installButton.title = ACTION_UPGRADE;
    }
    
    //otherwise disable uninstall
    else
    {
        //disable
        self.uninstallButton.enabled = NO;
    }
    
    //set delegate
    [self.window setDelegate:self];

    return;
}

//display (show) window
// center, make front, set bg to white, etc
-(void)display
{
    //center window
    [[self window] center];
    
    //show (now configured) windows
    [self showWindow:self];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }

    return;
}

//button handler for configure window
-(IBAction)configureButtonHandler:(id)sender {
    
    //action (tag)
    NSInteger action = ((NSButton*)sender).tag;
    
    os_log_debug(logHandle, "handling action click: %{public}@ (tag: %ld)", ((NSButton*)sender).title, (long)action);
    
    //leaving prefs view?
    // capture preferences
    if( (ACTION_SHOW_CONFIGURATIONS+1) == action)
    {
        //capture
        self.preferences = @{
            PREF_NOTARIZATION_MODE: @(self.notarizationMode.state),
            PREF_NOTARIZATION_ALL_MODE: @(self.notarizationAllMode.state),
            PREF_CLICKFIX_MODE: @(self.clickFixMode.state),
            PREF_CLICKFIX_HEURISTICS_MODE: @(self.clickFixHeuristicsMode.state)
        };
    }
    
    //process action
    switch(action)
    {
        //install/uninstall
        case ACTION_INSTALL_FLAG:
        case ACTION_UNINSTALL_FLAG:
        {
            //disable 'x' button
            // don't want user killing app during install/upgrade
            [[self.window standardWindowButton:NSWindowCloseButton] setEnabled:NO];
            
            //clear status msg
            self.statusMsg.stringValue = @"";
            
            //force redraw of status msg
            // sometime doesn't refresh (e.g. slow VM)
            self.statusMsg.needsDisplay = YES;
            
            //invoke logic to install/uninstall
            // do in background so UI doesn't block
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
               //install/uninstall
               [self lifeCycleEvent:action];
            });
            
            break;
        }
        
        //show 'full disk access' view
        case ACTION_SHOW_FDA:
        {
            //dbg msg
            os_log_debug(logHandle, "showing 'FDA' view");
            
            //remove title
            self.window.title = @"";
            
            //show view
            [self showView:self.diskAccessView firstResponder:self.diskAccessButton.tag];
            
            //start spinner
            [self.fdaActivityIndicator startAnimation:self];
            
            //in background
            // wait for daemon to set 'got FDA' preference
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
                //dbg msg
                os_log_debug(logHandle, "waiting for 'FDA' to be granted to daemon...");
                
                //still need FDA?
                while(YES == [self.configureObj shouldRequestFDA])
                {
                    //nap
                    [NSThread sleepForTimeInterval:0.25];
                }
                
                //dbg msg
                os_log_debug(logHandle, "daemon was granted 'FDA'!");
                
                //update UI
                dispatch_sync(dispatch_get_main_queue(),
                ^{
                    //hide spinner
                    self.fdaActivityIndicator.hidden = YES;
                    
                    //hide fda message
                    self.fdaMessage.hidden = YES;
                    
                    //enable 'next' button
                    ((NSButton*)[self.diskAccessView viewWithTag:ACTION_SHOW_SUPPORT]).enabled = YES;
                    
                    //make it first responder
                    [self.window makeFirstResponder:[self.diskAccessView viewWithTag:ACTION_SHOW_SUPPORT]];
                });
            });
            
            break;
        }
        
        //show configuration (of additional protections) view
        case ACTION_SHOW_CONFIGURATIONS:
        {
            //dbg msg
            os_log_debug(logHandle, "showing 'configuration' (of additional protections) view");
            
            //set (any) existing prefs
            NSDictionary* preferences = [NSDictionary dictionaryWithContentsOfFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE]];
            if(preferences) {
                self.notarizationMode.state = [preferences[PREF_NOTARIZATION_MODE] integerValue];
                self.notarizationAllMode.state = [preferences[PREF_NOTARIZATION_ALL_MODE] integerValue];
                self.clickFixMode.state = [preferences[PREF_CLICKFIX_MODE] integerValue];
                self.clickFixHeuristicsMode.state = [preferences[PREF_CLICKFIX_HEURISTICS_MODE] integerValue];
                
                //enable children
                if(self.notarizationMode.state == NSControlStateValueOn) {
                    self.notarizationAllMode.enabled = YES;
                }
                if(self.clickFixMode.state == NSControlStateValueOn) {
                    self.clickFixHeuristicsMode.enabled = YES;
                }
            }
                
            //show view
            [self showView:self.protectionsView firstResponder:ACTION_SHOW_SUPPORT];
            
            //unset window title
            self.window.title = @"";
            
            break;
        }
            
        //show 'support' view
        case ACTION_SHOW_SUPPORT:
        {
            //dbg msg
            os_log_debug(logHandle, "showing 'support' view");
            
            //show view
            [self showView:self.supportView firstResponder:self.supportButton.tag];
            
            //unset window title
            self.window.title = @"";
            
            break;
        }
            
        //support, yes!
        case ACTION_SUPPORT:
            
            //open URL
            // invokes user's default browser
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PATREON_URL]];
        
            //fall thru as we want to launch app and terminate
            
        //close
        // on non-error, launch login item
        case ACTION_CLOSE_FLAG:
        {
            //coming from support view?
            // launch helper/login item
            if(YES == self.supportView.window.isVisible)
            {
                //dbg msg
                os_log_debug(logHandle, "now launching: %{public}@", APP_NAME);
                
                //launch helper app
                // pass in preferences
                execTask(OPEN, @[[@"/Applications" stringByAppendingPathComponent:APP_NAME],
                    @"--args", INITIAL_LAUNCH,
                    PREF_NOTARIZATION_MODE, [self.preferences[PREF_NOTARIZATION_MODE] description],
                    PREF_NOTARIZATION_ALL_MODE, [self.preferences[PREF_NOTARIZATION_ALL_MODE] description],
                    PREF_CLICKFIX_MODE, [self.preferences[PREF_CLICKFIX_MODE] description],
                    PREF_CLICKFIX_HEURISTICS_MODE, [self.preferences[PREF_CLICKFIX_HEURISTICS_MODE] description]],
                    NO, NO);
            }
            
            //close window
            // triggers cleanup logic
            [self.window close];
            
            break;
        }
        
        //default
        default:
            
            break;
    }
    
    return;
}

//show view
// adds to main window, resizes, etc
-(void)showView:(NSView*)view firstResponder:(NSInteger)firstResponder
{
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //set white
        view.layer.backgroundColor = [NSColor whiteColor].CGColor;
    }
    
    //set content view size
    self.window.contentSize = view.frame.size;
    
    //update config view
    self.window.contentView = view;
    
    //(re)center
    [self.window center];

    //make 'next' button first responder
    // calling this without a timeout, sometimes fails :/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        
        //set first responder
        if(-1 != firstResponder)
        {
            //first responder
            [self.window makeFirstResponder:[view viewWithTag:firstResponder]];
        }
        
    });
    
    return;
}

//button handler for FDA issues
-(IBAction)fdaIssues:(id)sender
{
    //alert
    NSAlert *alert = nil;
    
    //alloc
    alert = [[NSAlert alloc] init];
    
    //title
    alert.messageText = @"Full Disk Access Issues?";
    
    //details
    alert.informativeText =  @"☑️ If 'BlockBlock' added/checked in System Preferenes, but this installer hasn't detected that fact, you may have to manully reboot the system to complete the install!";
    
    //add button
    [alert addButtonWithTitle:@"OK"];
    
    //set style
    alert.alertStyle = NSAlertStyleInformational;

    //show (modally)
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response)
    {
        #pragma unused(response)
        
        //enable 'next' button
        ((NSButton*)[self.diskAccessView viewWithTag:ACTION_SHOW_SUPPORT]).enabled = YES;
        
        //make it first responder
        [self.window makeFirstResponder:[self.diskAccessView viewWithTag:ACTION_SHOW_SUPPORT]];
    }];
    
    return;
}

//button handler
// open system prefs for full disk access
-(IBAction)openSystemPreferences:(id)sender {
    
    #pragma unused(sender)
    
    //frame
    CGRect frame = {0};
    
    //activity indicator
    NSProgressIndicator *activityIndicator = nil;
    
    //system prefs
    __block NSRunningApplication* systemPreferences = nil;
    
    //open `System Preferences`
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"]];
    
    //init frame
    frame = self.diskAccessButton.bounds;
    
    //adjust height and width
    frame.size.height = frame.size.height - 17;
    frame.size.width = frame.size.height;
    
    //adjust orgin
    frame.origin.x = frame.origin.x + 10;
    frame.origin.y = frame.origin.y + 7;
    
    //alloc spinner
    activityIndicator = [[NSProgressIndicator alloc] initWithFrame:frame];
    
    //set size
    activityIndicator.controlSize = NSControlSizeSmall;
    
    //set style
    activityIndicator.style = NSProgressIndicatorStyleSpinning;
    
    //start
    [activityIndicator startAnimation:self];
    
    //add to button
    [self.diskAccessButton addSubview:activityIndicator];
    
    //disable button
    self.diskAccessButton.enabled = NO;
        
    //wait till system preferences has finished launching
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //wait for app instance
        while(nil == systemPreferences)
        {
            //nap
            [NSThread sleepForTimeInterval:0.25];
            
            //get instance
            systemPreferences = [[NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.systempreferences"] firstObject];
        }
        
        //wait for app to finish launching
        while(YES != systemPreferences.finishedLaunching)
        {
            //nap
            [NSThread sleepForTimeInterval:0.25];
        }
        
        //dbg msg
        os_log_debug(logHandle, "System Preference has finished launching...");
        
        //give it an extra second
        [NSThread sleepForTimeInterval:1.00];
        
        //activate
        // and stop spinnner
        dispatch_async(dispatch_get_main_queue(), ^{
        
            //activate
            [systemPreferences activateWithOptions:NSApplicationActivateIgnoringOtherApps];
            
            //remove spinner
            [self.diskAccessButton.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                
                #pragma unused(idx)
                
                //is spinner?
                if(YES == [obj isKindOfClass:[NSProgressIndicator class]])
                {
                    //stop
                    [obj stopAnimation:nil];
                    
                    //remove spinner
                    [obj removeFromSuperview];
                    
                    //done
                    *stop = YES;
                }
            }];
        });
     });

    return;
}

//handler for (additiona) protections buttons
-(IBAction)protectionsButtonHandler:(id)sender {
    
    //button tag
    NSInteger tag = ((NSButton*)sender).tag;
    
    //button state
    NSInteger state = ((NSButton*)sender).state;
    
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
    
}

//button handler for '?' button (on an error)
// load objective-see's documentation for error(s) in default browser
-(IBAction)info:(id)sender
{
    #pragma unused(sender)
    
    //open URL
    // invokes user's default browser
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:ERRORS_URL]];
    
    return;
}

//perform install | uninstall via Control obj
// invoked on background thread so that UI doesn't block
-(void)lifeCycleEvent:(NSInteger)event
{
    //status var
    BOOL status = NO;
    
    //begin event
    // updates ui on main thread
    dispatch_sync(dispatch_get_main_queue(),
    ^{
        //begin
        [self beginEvent:event];
    });
    
    //in background
    // perform action (install | uninstall)
    status = [self.configureObj configure:event];
    
    //complete event
    // updates ui on main thread
    dispatch_async(dispatch_get_main_queue(),
    ^{
        //complete
        [self completeEvent:status event:event];
    });
    
    return;
}

//begin event
// basically just update UI
-(void)beginEvent:(NSInteger)event
{
    //status msg frame
    CGRect statusMsgFrame;
    
    //grab exiting frame
    statusMsgFrame = self.statusMsg.frame;
    
    //avoid activity indicator
    // shift frame shift delta
    statusMsgFrame.origin.x += FRAME_SHIFT;
    
    //update frame to align
    self.statusMsg.frame = statusMsgFrame;
    
    //align text left
    self.statusMsg.alignment = NSTextAlignmentLeft;
    
    //observe app activation
    // allows workaround where process indicator stops
    self.appActivationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSWorkspaceDidActivateApplicationNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
    {
        #pragma unused(notification)
        
        //show spinner
        self.activityIndicator.hidden = NO;
        
        //start spinner
        [self.activityIndicator startAnimation:nil];
        
    }];
    
    //install msg
    if(ACTION_INSTALL_FLAG == event)
    {
        //update status msg
        [self.statusMsg setStringValue:@"Installing..."];
    }
    //uninstall msg
    else
    {
        //update status msg
        [self.statusMsg setStringValue:@"Uninstalling..."];
    }
    
    //disable action button
    self.uninstallButton.enabled = NO;
    
    //disable cancel button
    self.installButton.enabled = NO;
    
    //show spinner
    self.activityIndicator.hidden = NO;
    
    //start spinner
    [self.activityIndicator startAnimation:nil];
    
    return;
}

//complete event
// update UI after background event has finished
-(void)completeEvent:(BOOL)success event:(NSInteger)event
{
    //status msg frame
    CGRect statusMsgFrame;
    
    //action
    NSString* action = nil;
    
    //result msg
    NSMutableString* resultMsg = nil;
    
    //msg font
    NSColor* resultMsgColor = nil;
    
    //remove app activation observer
    if(nil != self.appActivationObserver)
    {
        //remove
        [[NSNotificationCenter defaultCenter] removeObserver:self.appActivationObserver];
        
        //unset
        self.appActivationObserver = nil;
    }
    
    //set action msg for install
    if(ACTION_INSTALL_FLAG == event)
    {
        //set msg
        action = @"install";
    }
    //set action msg for uninstall
    else
    {
        //set msg
        action = @"uninstall";
    }
    
    //success
    if(YES == success)
    {
        //set result msg
        resultMsg = [NSMutableString stringWithFormat:@"☑️ %@: %@ed!\n", PRODUCT_NAME, action];
    }
    //failure
    else
    {
        //set result msg
        resultMsg = [NSMutableString stringWithFormat:@"⚠️ Error: %@ failed", action];
        
        //show 'get more info' button
        self.moreInfoButton.hidden = NO;
    }
    
    //stop/hide spinner
    [self.activityIndicator stopAnimation:nil];
    
    //hide spinner
    self.activityIndicator.hidden = YES;
    
    //grab exiting frame
    statusMsgFrame = self.statusMsg.frame;
    
    //shift back since activity indicator is gone
    statusMsgFrame.origin.x -= FRAME_SHIFT;
    
    //update frame to align
    self.statusMsg.frame = statusMsgFrame;
    
    //set font to bold
    self.statusMsg.font = [NSFont fontWithName:@"Menlo-Bold" size:13];
    
    //set msg color
    self.statusMsg.textColor = resultMsgColor;
    
    //set status msg
    self.statusMsg.stringValue = resultMsg;
    
    //install success?
    // set button title & tag for 'next'
    if( (YES == success) &&
        (ACTION_INSTALL_FLAG == event) )
    {
        //next
        self.installButton.title = ACTION_NEXT;
        
        //need FDA?
        // configure button for FDA request
        if(YES == [self.configureObj shouldRequestFDA])
        {
            //dbg msg
            os_log_debug(logHandle, "need to request FDA...");
            
            //set tag
            self.installButton.tag = ACTION_SHOW_FDA;
        }
        //no need
        // just set button to show config
        else
        {
            //dbg msg
            os_log_debug(logHandle, "got/have FDA already!");
            
            //set tag
            self.installButton.tag = ACTION_SHOW_CONFIGURATIONS;
        }
    }
    //otherwise
    // set button and tag for close/exit
    else
    {
        //close
        self.installButton.title = ACTION_CLOSE;
        
        //update it's tag
        // will allow button handler method process
        self.installButton.tag = ACTION_CLOSE_FLAG;
        
        //(re)enable 'x' button
        [[self.window standardWindowButton:NSWindowCloseButton] setEnabled:YES];
    }
    
    //enable
    self.installButton.enabled = YES;

    //...and highlighted
    [self.window makeFirstResponder:self.installButton];

    //(re)make window window key
    [self.window makeKeyAndOrderFront:self];
    
    //(re)make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//perform any cleanup/termination
// for now, just call into Config obj to remove helper
-(BOOL)cleanup
{
    //flag
    BOOL cleanedUp = NO;
    
    //dbg msg
    os_log_debug(logHandle, "cleaning up...");
    
    //remove helper
    if(YES != [self.configureObj removeHelper])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to remove config helper");
        
        //bail
        goto bail;
    }
    
    //happy
    cleanedUp = YES;
    
bail:

    return cleanedUp;
}

//automatically invoked when window is closing
// perform cleanup logic, then manually terminate app
-(void)windowWillClose:(NSNotification *)notification
{
    #pragma unused(notification)
    
    //cleanup in background
    // then exit application
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        //cleanup
        [self cleanup];
        
        //exit on main thread
        dispatch_async(dispatch_get_main_queue(),
        ^{
           //exit
           [NSApp terminate:self];
        });
    });

    return;
}

@end
