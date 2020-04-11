//
//  file: AppDelegate.m
//  project: BlockBlock (config)
//  description: application main/delegate
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "HelperComms.h"
#import "AppDelegate.h"

#import "Configure.h"
#import "utilities.h"
#import "AppDelegate.h"

#import <Security/Authorization.h>
#import <ServiceManagement/ServiceManagement.h>


@implementation AppDelegate

@synthesize xpcComms;
@synthesize statusMsg;
@synthesize aboutWindowController;
@synthesize configureWindowController;

//main app interface
-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
    #pragma unused(notification)
    
    //don't relaunch
    [NSApp disableRelaunchOnLogin];
    
    //center window
    [[[NSApplication sharedApplication] mainWindow] center];
    
    //show config window
    [self displayConfigureWindow];
    
    return;
}

//handler for menu
-(IBAction)menuHandler:(id)sender
{
    //handle selection
    switch(((NSButton*)sender).tag)
    {
        //about
        case MENU_ITEM_ABOUT:
        {
            //show about window
            [self displayAboutWindow];
            
            break;
        }
        //quit
        case MENU_ITEM_QUIT:
        {
            //exit
            [NSApp terminate:self];
        }
    }
    
    return;
}

//display configuration window
// kicks off logic for un/install
-(void)displayConfigureWindow
{
    //alloc/init
    configureWindowController = [[ConfigureWindowController alloc] initWithWindowNibName:@"ConfigureWindowController"];
    
    //display it
    // call this first to so that outlets are connected
    [self.configureWindowController display];
    
    //configure it
    [self.configureWindowController configure];
    
    return;
}

//menu handler for 'about'
-(void)displayAboutWindow
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
    
    return;
}

@end
