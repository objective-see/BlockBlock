//
//  file: AppDelegate.m
//  project: BlockBlock (login item)
//  description: app delegate for login item
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Carbon;
@import ApplicationServices;

#import "consts.h"
#import "Update.h"
#import "utilities.h"
#import "AppDelegate.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//alert windows
NSMutableDictionary* alerts = nil;

//xpc connection to daemon
XPCDaemonClient* xpcDaemonClient;

@implementation AppDelegate

@synthesize aboutWindowController;
@synthesize prefsWindowController;
@synthesize rulesWindowController;
@synthesize updateWindowController;
@synthesize statusBarItemController;

//app's main interface
-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
    //'no daemon' alert
    NSAlert* alert = nil;
    
    //os version
    NSOperatingSystemVersion osVersion = {0};
    
    //parent
    NSDictionary* parent = nil;
    
    //flag
    BOOL autoLaunched = NO;
    
    //preferences
    NSDictionary* preferences = nil;
    
    //allowed pids ('Click Fix' monitor)
    self.allowedTerminalPIDs = [NSMutableSet set];
    
    
    //get real parent
    parent = getRealParent(getpid());
    
    //dbg msg(s)
    os_log_debug(logHandle, "(real) parent: %{public}@", parent);
    
    //set auto launched flag (i.e. login item)
    if(YES == [parent[@"CFBundleIdentifier"] isEqualToString:@"com.apple.loginwindow"])
    {
        //set flag
        autoLaunched = YES;
    }

    //alloc array for alert (windows)
    alerts = [NSMutableDictionary dictionary];
    
    //init deamon comms
    // establishes connection to daemon
    xpcDaemonClient = [[XPCDaemonClient alloc] init];

    //get preferences
    // sends XPC message to daemon
    preferences = [xpcDaemonClient getPreferences];
    if(0 == preferences.count)
    {
        //init alert
        alert = [[NSAlert alloc] init];
        
        //set style
        alert.alertStyle = NSAlertStyleInformational;
        
        //set main text
        alert.messageText = @"Could Not Connect to the BlockBlock Daemon";
        
        //set informative test
        alert.informativeText = @"Please ensure that the BlockBlock daemon is currently running.";
        
        //add button
        [alert addButtonWithTitle:@"OK"];
        
        //show modal
        [alert runModal];
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "loaded preferences: %{public}@", preferences);
    
    //sanity check
    // make sure daemon has FDA
    if(YES != [preferences[PREF_GOT_FDA] boolValue])
    {
        //grab os version
        osVersion = NSProcessInfo.processInfo.operatingSystemVersion;
        
        //init alert
        alert = [[NSAlert alloc] init];
        
        //set style
        alert.alertStyle = NSAlertStyleInformational;
        
        //set main text
        alert.messageText = @"BlockBlock Not Active!";
        
        //macOS Ventura base was buggy
        if( (13 == osVersion.majorVersion) &&
            (0 == osVersion.minorVersion) &&
            (0 == osVersion.patchVersion) )
        {
            //set detailed text
            alert.informativeText = @"Please update your Mac to the latest version to fix this issue.\r\n\r\n(The orginal release of macOS Ventura contained a bug, that Apple has now fixed).";
        }
        else
        {
            //set detailed text
            alert.informativeText = @"Please ensure that the BlockBlock was granted \"Full Disk Access\" via System Preferences.\r\n\r\nIf it was, a manual reboot may fix the issue.";
        }
        
        //add button
        [alert addButtonWithTitle:@"OK"];
        
        //show modal
        [alert runModal];
        
        //bail
        goto bail;
    }
    
    //when user (manually) runs app
    // show the app's preferences window
    if( (YES != autoLaunched) &&
        (YES != [[[NSProcessInfo processInfo] arguments] containsObject:INITIAL_LAUNCH]) )
    {
        //show preferences
        [self showPreferences:nil];
    }
    
    //want app terminations
    // ...for 'ClickFix' protections
    [[[NSWorkspace sharedWorkspace] notificationCenter]
            addObserver:self
               selector:@selector(appTerminated:)
                   name:NSWorkspaceDidTerminateApplicationNotification
                 object:nil];
    
    //complete initializations
    [self completeInitialization:preferences];
    
bail:
        
    return;
}

//handle user double-clicks
// app is (likely) already running as login item, so show (or) activate window
-(BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)hasVisibleWindows
{
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked (hasVisibleWindows: %d)", __PRETTY_FUNCTION__, hasVisibleWindows);
    
    //no visible window(s)
    // default to show preferences
    if(YES != hasVisibleWindows)
    {
        //show prefs
        [self showPreferences:nil];
    }
    
    return NO;
}

//'rules' menu item handler
// alloc and show rules window
-(IBAction)showRules:(id)sender
{
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //alloc rules window controller
    if(nil == self.rulesWindowController)
    {
        //dbg msg
        os_log_debug(logHandle, "allocating rules window controller...");
        
        //alloc
        rulesWindowController = [[RulesWindowController alloc] initWithWindowNibName:@"Rules"];
    }
    
    //configure (UI)
    [self.rulesWindowController configure];
    
    //make active
    [self makeActive:self.rulesWindowController];
    
    return;
}

//'preferences' menu item handler
// alloc and show preferences window
-(IBAction)showPreferences:(id)sender
{
    //alloc prefs window controller
    if(nil == self.prefsWindowController)
    {
        //alloc
        prefsWindowController = [[PrefsWindowController alloc] initWithWindowNibName:@"Preferences"];
    }
    
    //make active
    [self makeActive:self.prefsWindowController];
    
    return;
}

//'about' menu item handler
// alloc/show the about window
-(IBAction)showAbout:(id)sender
{
    //alloc/init settings window
    if(nil == self.aboutWindowController)
    {
        //alloc/init
        aboutWindowController = [[AboutWindowController alloc] initWithWindowNibName:@"AboutWindow"];
    }
    
    //center window
    [[self.aboutWindowController window] center];
    
    //show it
    [self.aboutWindowController showWindow:self];
    
    /*
    //invoke function in background that will make window modal
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //make modal
        makeModal(self.aboutWindowController);
        
    });
    */
    
    return;
}

//close window handler
// close rules || pref window
-(IBAction)closeWindow:(id)sender {
    
    //key window
    NSWindow *keyWindow = nil;
    
    //get key window
    keyWindow = [[NSApplication sharedApplication] keyWindow];
    
    //dbg msg
    os_log_debug(logHandle, "close window request (key window: %{public}@)", keyWindow);

    //close
    // but only for rules/pref/about window
    if( (keyWindow != self.aboutWindowController.window) &&
        (keyWindow != self.prefsWindowController.window) &&
        (keyWindow != self.rulesWindowController.window) )
    {
        //dbg msg
        os_log_debug(logHandle, "key window is not rules or pref window, so ignoring...");
        
        //ignore
        goto bail;
    }
    
    //close
    [keyWindow close];
    
    //set activation policy
    [self setActivationPolicy];
    
bail:
    
    return;
}

//make a window control/window front/active
-(void)makeActive:(NSWindowController*)windowController
{
    //make foreground
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    
    //center
    [windowController.window center];

    //show it
    [windowController showWindow:self];
    
    //make it key window
    [[windowController window] makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//toggle (status) bar icon
-(void)toggleIcon:(NSDictionary*)preferences
{
    //dbg msg
    os_log_debug(logHandle, "toggling icon state");
    
    //should run with no icon?
    // init and show status bar item
    if(YES != [preferences[PREF_NO_ICON_MODE] boolValue])
    {
        //already showing?
        if(nil != self.statusBarItemController)
        {
            //bail
            goto bail;
        }
        
        //alloc/load status bar icon/menu
        // will configure, and show popup/menu
        statusBarItemController = [[StatusBarItem alloc] init:self.statusMenu preferences:(NSDictionary*)preferences];
    }
    
    //run without icon
    // remove status bar item
    else
    {
        //already removed?
        if(nil == self.statusBarItemController)
        {
            //bail
            goto bail;
        }
        
        //remove status item
        [self.statusBarItemController removeStatusItem];
        
        //unset
        self.statusBarItemController = nil;
    }
    
bail:
    
    return;
}

//set app foreground/background
-(void)setActivationPolicy
{
    //visible window
    BOOL visibleWindow = NO;
    
    //dbg msg
    os_log_debug(logHandle, "setting app's activation policy");
    
    //dbg msg
    os_log_debug(logHandle, "windows: %{public}@", NSApp.windows);
    
    //find any visible windows
    for(NSWindow* window in NSApp.windows)
    {
        //ignore status bar
        if(YES == [window.className isEqualToString:@"NSStatusBarWindow"])
        {
            //skip
            continue;
        }
        
        //visible?
        if(YES == window.isVisible)
        {
            //set flag
            visibleWindow = YES;
            
            //done
            break;
        }
    }
    
    //any windows?
    //bring app to foreground
    if(YES == visibleWindow)
    {
        //dbg msg
        os_log_debug(logHandle, "window(s) visible, setting policy: NSApplicationActivationPolicyRegular");
        
        //foreground
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    }
    
    //no more windows
    // send app to background
    else
    {
        //dbg msg
        os_log_debug(logHandle, "window(s) not visible, setting policy: NSApplicationActivationPolicyAccessory");
        
        //background
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    }
    
    return;
}


//finish up initializations
// based on prefs, show status bar, check for updates, etc...
-(void)completeInitialization:(NSDictionary*)preferences
{
    //run with status bar icon?
    if(YES != [preferences[PREF_NO_ICON_MODE] boolValue])
    {
        //alloc/load nib
        statusBarItemController = [[StatusBarItem alloc] init:self.statusMenu preferences:(NSDictionary*)preferences];
        
        //dbg msg
        os_log_debug(logHandle, "initialized/loaded status bar (icon/menu)");
    }
    else
    {
        //dbg msg
        os_log_debug(logHandle, "running in 'no icon' mode (so no need for status bar)");
    }
    
    //automatically check for updates?
    if(YES != [preferences[PREF_NO_UPDATE_MODE] boolValue])
    {
        //after a 30 seconds
        // check for updates in background
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
        {
            //dbg msg
            os_log_debug(logHandle, "checking for update");
           
            //check
            [self check4Update];
       });
    }
    
    //monitor for "ClickFix" attacks?
    // after slight delay to make sure 'Accessibility' prompt shows up
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        //'ClickFix' mode?
        if([preferences[PREF_CLICKFIX_MODE] boolValue]) {
            
            //start
            [self startClickFixMonitor:YES];
        }
        
    });

    return;
}

//call into Update obj
// check to see if there an update?
-(void)check4Update
{
    //update obj
    Update* update = nil;
    
    //init update obj
    update = [[Update alloc] init];
    
    //check for update
    // ->'updateResponse newVersion:' method will be called when check is done
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
    //handle response
    // new version, show popup
    switch (result)
    {
        //error
        case -1:
            
            //err msg
            os_log_error(logHandle, "ERROR: update check failed");
            break;
            
        //no updates
        case 0:
            
            //dbg msg
            os_log_debug(logHandle, "no updates available");
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

//install 'ClickFix' monitor
-(void)startClickFixMonitor:(BOOL)shouldPrompt {
    
    static CFAbsoluteTime pollStart = 0;
    
    //common terminal apps
    static NSSet* terminalBundleIDs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        terminalBundleIDs = [NSSet setWithArray:@[
            @"com.apple.Terminal",
            @"com.googlecode.iterm2",
            @"com.mitchellh.ghostty",
            @"net.kovidgoyal.kitty",
            @"dev.warp.Warp-Stable"
        ]];
    });
    
    os_log_debug(logHandle, "'%s' invoked", __PRETTY_FUNCTION__);
    
    if (self.clickFixMonitor) {
        return;
    }
    
    //do we need 'Accessibility'?
    if(!AXIsProcessTrusted()) {
        
        os_log_debug(logHandle, "'AXIsProcessTrusted' returned: NO");
            
        //should prompt
        if(shouldPrompt) {
            
            //start timeout
            pollStart = CFAbsoluteTimeGetCurrent();
            
            //activate
            [NSApp activateIgnoringOtherApps:YES];
            
            os_log_debug(logHandle, "triggering 'Accessibility' prompt");
        
            //trigger prompt to user to allow app
            AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{
                (__bridge id)kAXTrustedCheckOptionPrompt: @YES
            });
        }
        
        //hit timeout?
        // unset preference
        if(pollStart > 0 && (CFAbsoluteTimeGetCurrent() - pollStart) > 30.0) {
            
            os_log_error(logHandle, "ERROR: timed out waiting for Accessibility");
            
            //reset stuff
            pollStart = 0;
            [xpcDaemonClient updatePreferences:@{PREF_CLICKFIX_MODE:@NO}];
            return;
        }
        
        //(re)call this function for poll/check if we got 'Accessibility'
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [weakSelf startClickFixMonitor:NO];
        });
        
        return;
    }
    
    //now, we have 'Accessibility' so can install monitor
    
    //reset
    pollStart = 0;
    
    os_log_debug(logHandle, "'Accessibility' granted, will install monitor");

    //install monitor
    // note, we only care about '⌘+v' in Terminal
    self.clickFixMonitor =
    [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^(NSEvent *event) {
        
        //'⌘' gotta be pressed
        if (!(event.modifierFlags & NSEventModifierFlagCommand)) {
            return;
        }
        
        //and also 'v'
        if (![[event.charactersIgnoringModifiers lowercaseString] isEqualToString:@"v"]) {
            return;
        }

        //check if pasting into Terminal
        dispatch_async(dispatch_get_main_queue(), ^{
        
            //front app
            NSRunningApplication* frontApp = NSWorkspace.sharedWorkspace.frontmostApplication;
            if(!frontApp) {
                return;
            }
            
            os_log_debug(logHandle, "'ClickFix' monitor: detected '⌘+v' in %@", frontApp.localizedName);
            
            //gotta be a terminal app
            if(![terminalBundleIDs containsObject:frontApp.bundleIdentifier]) {
                return;
            }
            
            //user said "Allow until Terminal quits"?
            if([self.allowedTerminalPIDs containsObject:@(frontApp.processIdentifier)]) {
                os_log_debug(logHandle, "'ClickFix' monitor: Terminal was previously allowed");
                return;
            }
            
            //grab clipboard
            NSString* clipboard = [NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString];
            
            //ignore if blank
            if(!clipboard.length) {
                return;
            }
            
            //stop terminal
            kill(frontApp.processIdentifier, SIGSTOP);
            
            os_log_debug(logHandle, "SIGSTOP'd Terminal");
            
            //truncate
            NSString *displayClip = clipboard.length > 1000 ?
                    [[clipboard substringToIndex:1000] stringByAppendingString:@"…"] :
            clipboard;
                
            //scrollable text view for clipboard content
            NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 450, 120)];
            scrollView.hasVerticalScroller = YES;
            scrollView.borderType = NSBezelBorder;
            
            NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 450, 120)];
            textView.editable = NO;
            textView.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
            textView.string = displayClip;
            textView.backgroundColor = [NSColor controlBackgroundColor];
            scrollView.documentView = textView;
            
            //alert
            NSAlert *alert = [[NSAlert alloc] init];
            alert.icon = [NSImage imageNamed:@"AppIcon"];
            alert.messageText = [NSString stringWithFormat:
                @"BlockBlock: Paste into %@ Detected", frontApp.localizedName];
            
            alert.informativeText = @"A website may have tricked you into copying a malicious command. "
                                    @"Please review the content below before allowing!";
            alert.alertStyle = NSAlertStyleCritical;
            alert.accessoryView = scrollView;
            alert.showsSuppressionButton = YES;
            alert.suppressionButton.title = [NSString stringWithFormat:
                @"Allow pastes until %@ quits", frontApp.localizedName];
            [alert addButtonWithTitle:@"Block"];
            [alert addButtonWithTitle:@"Allow"];
            
            //remove key equivalents so Enter doesn't trigger either
            for(NSButton* button in alert.buttons) {
                button.keyEquivalent = @"";
            }
            
            //make block reddish
            if(@available(macOS 11.0, *))
            {
                [alert.buttons[0] setHasDestructiveAction:YES];
            }
            
            //bring to front
            // as we're a LSUIElement app
            [self setActivationPolicy];
            [NSApp requestUserAttention:NSCriticalRequest];
            [NSApp activateIgnoringOtherApps:YES];
            
            //show alert
            NSModalResponse response = [alert runModal];
            
            //action: allow?
            if(response == NSAlertSecondButtonReturn) {
                
                //allow until Terminal quits?
                if(alert.suppressionButton.state == NSControlStateValueOn) {
                    [self.allowedTerminalPIDs addObject:@(frontApp.processIdentifier)];
                }
            }

            //action: block
            else {
                os_log(logHandle, "clearing Pasteboard to block");
                [NSPasteboard.generalPasteboard clearContents];
            }
                
            //resume Terminal
            kill(frontApp.processIdentifier, SIGCONT);
            
            os_log(logHandle, "SIGCONT'd Terminal");
            
            //give Terminal focus back
            [frontApp activateWithOptions:NSApplicationActivateIgnoringOtherApps];
            
            //back to background
            [self setActivationPolicy];
            
        });
    }];
    
    os_log_debug(logHandle, "'ClickFix' monitor installed");
}

//handler for app termination
// just reset allowed (Terminal) pid
-(void)appTerminated:(NSNotification *)notification
{
    NSRunningApplication *app = notification.userInfo[NSWorkspaceApplicationKey];
    if(app) {
        [self.allowedTerminalPIDs removeObject:@(app.processIdentifier)];
    }
}

//remove 'ClickFix' monitor
-(void)stopClickFixMonitor {
    
    //remove
    if(self.clickFixMonitor) {
        [NSEvent removeMonitor:self.clickFixMonitor];
        self.clickFixMonitor = nil;
        
        //reset
        [self.allowedTerminalPIDs removeAllObjects];
    }
}

@end
