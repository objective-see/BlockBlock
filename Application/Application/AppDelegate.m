//
//  file: AppDelegate.m
//  project: BlockBlock (login item)
//  description: app delegate for login item
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Update.h"
#import "logging.h"
#import "utilities.h"
#import "AppDelegate.h"

/* GLOBALS */

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
    
    //parent
    NSDictionary* parent = nil;
    
    //flag
    BOOL autoLaunched = NO;
    
    //preferences
    NSDictionary* preferences = nil;
    
    //get real parent
    parent = getRealParent(getpid());
    
    //dbg msg(s)
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"(real) parent: %@", parent]);
    
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
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded preferences: %@", preferences]);
    
    //sanity check
    // make sure daemon has FDA
    if(YES != [preferences[PREF_GOT_FDA] boolValue])
    {
        //init alert
        alert = [[NSAlert alloc] init];
        
        //set style
        alert.alertStyle = NSAlertStyleInformational;
        
        //set main text
        alert.messageText = @"BlockBlock Not Active!";
        
        //set detailed text
        alert.informativeText = @"Please ensure that the BlockBlock daemon was granted \"Full Disk Access\" via System Preferences.\r\n\r\nIf it was, a manual reboot may fix the issue!";
        
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
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"method '%s' invoked (hasVisibleWindows: %d)", __PRETTY_FUNCTION__, hasVisibleWindows]);
    
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
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"method '%s' invoked", __PRETTY_FUNCTION__]);
    
    //alloc rules window controller
    if(nil == self.rulesWindowController)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"allocating rules window controller...");
        
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
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"close window request (key window: %@)", keyWindow]);

    //close
    // but only for rules/pref/about window
    if( (keyWindow != self.aboutWindowController.window) &&
        (keyWindow != self.prefsWindowController.window) &&
        (keyWindow != self.rulesWindowController.window) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"key window is not rules or pref window, so ignoring...");
        
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
    logMsg(LOG_DEBUG, @"toggling icon state");
    
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
    logMsg(LOG_DEBUG, @"setting app's activation policy");
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"windows: %@", NSApp.windows]);
    
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
        logMsg(LOG_DEBUG, @"window(s) visible, setting policy: NSApplicationActivationPolicyRegular");
        
        //foreground
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    }
    
    //no more windows
    // send app to background
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"window(s) not visible, setting policy: NSApplicationActivationPolicyAccessory");
        
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
        logMsg(LOG_DEBUG, @"initialized/loaded status bar (icon/menu)");
    }
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"running in 'no icon' mode (so no need for status bar)");
    }
    
    //automatically check for updates?
    if(YES != [preferences[PREF_NO_UPDATE_MODE] boolValue])
    {
        //after a 30 seconds
        // check for updates in background
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"checking for update");
           
            //check
            [self check4Update];
       });
    }
    
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
            logMsg(LOG_ERR, @"update check failed");
            break;
            
        //no updates
        case 0:
            
            //dbg msg
            logMsg(LOG_DEBUG, @"no updates available");
            break;
            
        //new version
        case 1:
            
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"a new version (%@) is available", newVersion]);

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

@end
