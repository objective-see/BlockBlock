//
//  file: ConfigureWindowController.m
//  project: BlockBlock (config)
//  description: install/uninstall window logic
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "Configure.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "ConfigureWindowController.h"

@implementation ConfigureWindowController

@synthesize statusMsg;
@synthesize configureObj;
@synthesize diskAccessView;
@synthesize moreInfoButton;
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
    [self.statusMsg setStringValue:@"Protection against persistent malware 👾"];
    
    //app already installed?
    // enable 'uninstall' button
    // change 'install' button to say 'upgrade'
    if(YES == isInstalled)
    {
        //enable 'uninstall'
        self.uninstallButton.enabled = YES;
        
        //set to 'upgrade'
        self.installButton.title = ACTION_UPGRADE;
    }
    
    //otherwise disable
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
// install/uninstall/close logic
-(IBAction)configureButtonHandler:(id)sender
{
    //action
    NSInteger action = 0;

    //grab tag
    action = ((NSButton*)sender).tag;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"handling action click: %@ (tag: %ld)", ((NSButton*)sender).title, (long)action]);
    
    //process button
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
            logMsg(LOG_DEBUG, @"showing 'FDA' view");
            
            //remove title
            self.window.title = @"";
            
            //show view
            [self showView:self.diskAccessView firstResponder:self.diskAccessButton];
            
            //register for deactivation
            // user must launch / interact w/ System Prefs before we enable 'next' button
            [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(appDeactivated:) name:NSWorkspaceDidDeactivateApplicationNotification object:nil];
            
            break;
        }
        //show 'support' view
        // a) kick off main app
        // b) load the launch daemon as we (now) have FDA
        case ACTION_SHOW_SUPPORT:
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"showing 'support' view");
            
            //did we have to request for 'FDA'?
            // if so, try start the deamon now (again)
            if(YES == self.configureObj.requestFDA)
            {
                //load daemon in background
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                ^{
                    //load launch daemon
                    if(YES == [self.configureObj toggleDaemon:YES])
                    {
                        //err msg
                        logMsg(LOG_ERR, @"failed to load launch daemon");
                        
                        //helper app will detect error & alert user...
                    }
                    //dbg msg
                    else
                    {
                        //dbg msg
                        logMsg(LOG_DEBUG, @"loaded launch daemon...");
                    }
                });
            }
                
            //launch helper app
            execTask(OPEN, @[[@"/Applications" stringByAppendingPathComponent:APP_NAME], @"--args", INITIAL_LAUNCH], NO, NO);
            
            //show view
            [self showView:self.supportView firstResponder:self.supportButton];
            
            //(re)enable 'x' button
            [self.window standardWindowButton:NSWindowCloseButton].enabled = YES;
            
            //unset window title
            self.window.title = @"";
            
            break;
        }
            
        //support, yes!
        case ACTION_SUPPORT:
            
            //open URL
            // invokes user's default browser
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PATREON_URL]];
        
            //fall thru as we want to terminate app
            
        //close (on error)
        case ACTION_CLOSE_FLAG:
        {
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
-(void)showView:(NSView*)view firstResponder:(NSButton*)firstResponder
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

    //make 'next' button first responder
    // calling this without a timeout, sometimes fails :/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        
        //set first responder
        [self.window makeFirstResponder:firstResponder];
        
    });
    
    return;
}

//callback for 'NSWorkspaceDidDeactivateApplicationNotification'
// will be trigged when user interacts with 'System Prefs' able, so enable 'Next' button then
-(void)appDeactivated:(NSNotification *)notification
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"'%s' invoked", __PRETTY_FUNCTION__]);
    
    //enable 'next' button after a bit
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
           
        //enable
        ((NSButton*)[self.diskAccessView viewWithTag:ACTION_SHOW_SUPPORT]).enabled = YES;
           
    });
    
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
        logMsg(LOG_DEBUG, @"System Preference has finished launching...");
        
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

//button handler for '?' button (on an error)
// load objective-see's documentation for error(s) in default browser
-(IBAction)info:(id)sender
{
    #pragma unused(sender)
    
    //open URL
    // invokes user's default browser
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:ERRORS_URL]];
    
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
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"request FDA? %d", configureObj.requestFDA]);
    
        //need FDA?
        // configure button for FDA request
        if(YES == configureObj.requestFDA)
        {
            //set tag
            self.installButton.tag = ACTION_SHOW_FDA;
        }
        //no need
        // just configure button to show support
        else
        {
            //set tag
            self.installButton.tag = ACTION_SHOW_SUPPORT;
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
    logMsg(LOG_DEBUG, @"cleaning up...");
    
    //remove helper
    if(YES != [self.configureObj removeHelper])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to remove config helper");
        
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
