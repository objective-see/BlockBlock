//
//  file: AlertWindowController.m
//  project: BlockBlock (login item)
//  description: window controller for main firewall alert
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import <sys/socket.h>


#import "consts.h"
#import "logging.h"
#import "utilities.h"
#import "FileMonitor.h"
#import "AppDelegate.h"
#import "XPCDaemonClient.h"
#import "AlertWindowController.h"

@implementation AlertWindowController

@synthesize alert;
//@synthesize isTempRule;
@synthesize processIcon;
@synthesize processName;
@synthesize processSummary;
@synthesize ancestryButton;
@synthesize ancestryPopover;
@synthesize processHierarchy;
@synthesize virusTotalButton;
@synthesize signingInfoButton;
@synthesize virusTotalPopover;

//center window
// also, transparency
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    //full size content view for translucency
    self.window.styleMask = self.window.styleMask | NSWindowStyleMaskFullSizeContentView;
    
    //title bar; translucency
    self.window.titlebarAppearsTransparent = YES;
    
    //move via background
    self.window.movableByWindowBackground = YES;
    
    return;
}

//delegate method
// populate/configure alert window
-(void)windowDidLoad
{
    //paragraph style (for temporary label)
    NSMutableParagraphStyle* paragraphStyle = nil;
    
    //title attributes (for temporary label)
    NSMutableDictionary* titleAttributes = nil;
    
    //init paragraph style
    paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    
    //init dictionary for title attributes
    titleAttributes = [NSMutableDictionary dictionary];
    
    //extract process hierarchy
    self.processHierarchy = alert[ALERT_PROCESS_ANCESTORS];
    
    //disable ancestory button if no ancestors
    if(0 == self.processHierarchy.count)
    {
        //disable
        self.ancestryButton.enabled = NO;
    }
    
    /* TOP */
    
    //set process icon
    self.processIcon.image = getIconForProcess(self.alert[ALERT_PROCESS_PATH]);
    
    //process signing info
    [self setSigningIcon];
    
    //set process name
    self.processName.stringValue = self.alert[ALERT_PROCESS_NAME];
    
    //alert message
    self.alertMessage.stringValue = self.alert[ALERT_MESSAGE];
    
    /* BOTTOM */
    
    //set summary
    // name and pid
    self.processSummary.stringValue = [NSString stringWithFormat:@"%@ (pid: %@)", self.alert[ALERT_PROCESS_NAME], self.alert[ALERT_PROCESS_ID]];
    
    //args
    if(0 != [self.alert[ALERT_PROCESS_ARGS] count])
    {
        //add each arg
        // note: skip first, since the process name
        [self.alert[ALERT_PROCESS_ARGS] enumerateObjectsUsingBlock:^(NSString* argument, NSUInteger index, BOOL* stop) {
            
            //skip first arg
            if(0 == index) return;
            
            //add argument
            self.processArgs.stringValue = [self.processArgs.stringValue stringByAppendingFormat:@"%@ ", argument];
            
        }];
    }
    //no args
    else
    {
        //none
        self.processArgs.stringValue = @"none";
    }
    
    //process path
    self.processPath.stringValue = self.alert[ALERT_PROCESS_PATH];
    
    //start up file/item
    self.startupItem.stringValue = self.alert[ALERT_ITEM_NAME];
    
    //start up item/file path
    self.startupFile.stringValue = self.alert[ALERT_ITEM_FILE];
    
    //start item object
    // binary, cmd, etc...
    self.startupObject.stringValue = self.alert[ALERT_ITEM_OBJECT];
    
    //add timestamp
    self.timeStamp.stringValue = self.alert[ALERT_TIMESTAMP];
    
    //set paragraph style to left
    paragraphStyle.alignment = NSTextAlignmentLeft;
    
    //set baseline attribute for temporary label
    titleAttributes[NSBaselineOffsetAttributeName] = [NSNumber numberWithDouble:((self.tempRule.font.xHeight/2.0) - 1.0)];
    
    //set paragraph attribute for temporary label
    titleAttributes[NSParagraphStyleAttributeName] = paragraphStyle;
    
    //set color to label default
    titleAttributes[NSForegroundColorAttributeName] = [NSColor labelColor];
    
    //set font
    titleAttributes[NSFontAttributeName] = [NSFont fontWithName:@"Menlo-Regular" size:13];
    
    //temp rule button label
    self.tempRule.attributedTitle = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" temporarily (pid: %@)", [self.alert[ALERT_PROCESS_ID] stringValue]] attributes:titleAttributes];
    
    //restricted file?
    // configure buttons
    if(YES == [self.alert[ALERT_ITEM_FILE_RESTRICTED] boolValue])
    {
        //disable block
        self.blockButton.enabled = NO;
        
        //change title of allow
        self.allowButton.title = @"Ok";
        
        //disable temp
        self.tempRule.enabled = NO;
    }
    //normal file
    // (re)set buttons
    else
    {
        //disable block
        self.blockButton.enabled = YES;
        
        //change title of allow
        self.allowButton.title = @"Allow";
        
        //enable temp
        self.tempRule.enabled = YES;
    }
    
    //show touch bar
    [self initTouchBar];
    
bail:
    
    return;
}

//set signing icon
-(void)setSigningIcon
{
    //flags
    uint32_t csFlags = 0;
    
    //image
    NSImage* image = nil;
    
    //signing info
    NSDictionary* signingInfo = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"processing signing information");
    
    //default to unknown
    image = [NSImage imageNamed:@"SignedUnknown"];
    
    //extract signing info
    signingInfo = self.alert[ALERT_PROCESS_SIGNING_INFO];
    
    //extract flags
    csFlags = [signingInfo[CS_FLAGS] unsignedIntValue];
    
    //unsigned?
    if(0 == csFlags)
    {
        //unsigned
        image = [NSImage imageNamed:@"Unsigned"];
        
        //bail
        goto bail;
    }
    
    //validly signed?
    if(csFlags & CS_VALID)
    {
        //apple?
        if(YES == [signingInfo[PLATFORM_BINARY] boolValue])
        {
            //apple
            image = [NSImage imageNamed:@"SignedApple"];
        }
        
        //signed by dev id/ad hoc, etc
        else
        {
            //set icon
            image = [NSImage imageNamed:@"Signed"];
        }
        
        //bail
        goto bail;
    }
    
bail:
    
    //set image
    signingInfoButton.image = image;
    
    return;
}

//automatically invoked when user clicks signing icon
// depending on state, show/populate the popup, or close it
-(IBAction)signingInfoButtonHandler:(id)sender
{
    //view controller
    SigningInfoViewController* popover = nil;
    
    //open popover
    if(NSControlStateValueOn == self.signingInfoButton.state)
    {
        //grab delegate
        popover = (SigningInfoViewController*)self.signingInfoPopover.delegate;
        
        //set icon image
        popover.icon.image = self.signingInfoButton.image;
        
        //set alert info
        popover.alert = self.alert;
        
        //show popover
        [self.signingInfoPopover showRelativeToRect:[self.signingInfoButton bounds] ofView:self.signingInfoButton preferredEdge:NSMaxYEdge];
    }
    
    //close popover
    else
    {
        //close
        [self.signingInfoPopover close];
    }
    
    return;
}

//automatically invoked when user clicks process vt button
// depending on state, show/populate the popup, or close it
-(IBAction)vtButtonHandler:(id)sender
{
    //view controller
    VirusTotalViewController* popoverVC = nil;
    
    //open popover
    if(NSControlStateValueOn == self.virusTotalButton.state)
    {
        //grab
        popoverVC = (VirusTotalViewController*)self.virusTotalPopover.delegate;
        
        //set name
        popoverVC.itemName = self.processName.stringValue;
        
        //set path
        popoverVC.itemPath = self.processPath.stringValue;
        
        //show popover
        [self.virusTotalPopover showRelativeToRect:[self.virusTotalButton bounds] ofView:self.virusTotalButton preferredEdge:NSMaxYEdge];
    }
    
    //close popover
    else
    {
        //close
        [self.virusTotalPopover close];
    }
    
    return;
}

//invoked when user clicks process ancestry button
// depending on state, show/populate the popup, or close it
-(IBAction)ancestryButtonHandler:(id)sender
{
    //open popover
    if(NSControlStateValueOn == self.ancestryButton.state)
    {
        //add the index value to each process in the hierarchy
        // used to populate outline/table
        for(NSUInteger i = 0; i < processHierarchy.count; i++)
        {
            //set index
            processHierarchy[i][@"index"] = [NSNumber numberWithInteger:i];
        }

        //set process hierarchy
        self.ancestryViewController.processHierarchy = processHierarchy;
        
        //dynamically (re)size popover
        [self setPopoverSize];
        
        //reload it
        [self.ancestryOutline reloadData];
        
        //auto-expand
        [self.ancestryOutline expandItem:nil expandChildren:YES];
        
        //show popover
        [self.ancestryPopover showRelativeToRect:[self.ancestryButton bounds] ofView:self.ancestryButton preferredEdge:NSMaxYEdge];
    }
    
    //close popover
    else
    {
        //close
        [self.ancestryPopover close];
    }
    
    return;
}


//set the popover window size
// make it roughly fit to content
-(void)setPopoverSize
{
    //popover's frame
    CGRect popoverFrame = {0};
    
    //required height
    CGFloat popoverHeight = 0.0f;
    
    //text of current row
    NSString* currentRow = nil;
    
    //width of current row
    CGFloat currentRowWidth = 0.0f;
    
    //length of max line
    CGFloat maxRowWidth = 0.0f;
    
    //extra rows
    NSUInteger extraRows = 0;
    
    //when hierarchy is less than 4
    // ->set (some) extra rows
    if(self.ancestryViewController.processHierarchy.count < 4)
    {
        //5 total
        extraRows = 4 - self.ancestryViewController.processHierarchy.count;
    }
    
    //calc total window height
    // ->number of rows + extra rows, * height
    popoverHeight = (self.ancestryViewController.processHierarchy.count + extraRows + 2) * [self.ancestryOutline rowHeight];
    
    //get window's frame
    popoverFrame = self.ancestryView.frame;
    
    //calculate max line width
    for(NSUInteger i=0; i<self.ancestryViewController.processHierarchy.count; i++)
    {
        //generate text of current row
        currentRow = [NSString stringWithFormat:@"%@ (pid: %@)", self.ancestryViewController.processHierarchy[i][@"name"], [self.ancestryViewController.processHierarchy lastObject][@"pid"]];
        
        //calculate width
        // ->first w/ indentation
        currentRowWidth = [self.ancestryOutline indentationPerLevel] * (i+1);
        
        //calculate width
        // ->then size of string in row
        currentRowWidth += [currentRow sizeWithAttributes: @{NSFontAttributeName: self.ancestryTextCell.font}].width;
        
        //save it greater than max
        if(maxRowWidth < currentRowWidth)
        {
            //save
            maxRowWidth = currentRowWidth;
        }
    }
    
    //add some padding
    // ->scroll bar, etc
    maxRowWidth += 50;
    
    //set height
    popoverFrame.size.height = popoverHeight;
    
    //set width
    popoverFrame.size.width = maxRowWidth;
    
    //set new frame
    self.ancestryView.frame = popoverFrame;
    
    return;
}

//close any open popups
-(void)closePopups
{
    //virus total popup
    if(NSControlStateValueOn == self.virusTotalButton.state)
    {
        //close
        [self.virusTotalPopover close];
    
        //set button state to off
        self.virusTotalButton.state = NSControlStateValueOff;
    }
    
    //process ancestry popup
    if(NSControlStateValueOn == self.ancestryButton.state)
    {
        //close
        [self.ancestryPopover close];
        
        //set button state to off
        self.ancestryButton.state = NSControlStateValueOff;
    }
    
    //signing info popup
    if(NSControlStateValueOn == self.signingInfoButton.state)
    {
        //close
        [self.signingInfoPopover close];
        
        //set button state to off
        self.signingInfoButton.state = NSControlStateValueOff;
    }
    
    return;
}

//handler for user's response to alert
-(IBAction)handleUserResponse:(id)sender
{
    //response to daemon
    NSMutableDictionary* alertResponse = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"user clicked: %ld", (long)((NSButton*)sender).tag]);

    //ensure popups are closed
    [self closePopups];
    
    //close window
    [self.window close];
    
    //init alert response
    // start w/ copy of received alert
    alertResponse = [self.alert mutableCopy];
    
    //add current user
    alertResponse[ALERT_USER] = [NSNumber numberWithUnsignedInt:getuid()];
    
    //add action scope
    alertResponse[ALERT_ACTION_SCOPE] = [NSNumber numberWithInteger:self.actionScope.indexOfSelectedItem];
    
    //add user response
    alertResponse[ALERT_ACTION] = [NSNumber numberWithLong:((NSButton*)sender).tag];
    
    //add button state for 'temp rule'
    alertResponse[ALERT_TEMPORARY] = [NSNumber numberWithBool:(BOOL)self.tempRule.state];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"responding to daemon, alert: %@", alertResponse]);
    
    //send response to daemon
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).xpcDaemonClient alertReply:alertResponse];
    
    //(shortly thereafter) refresh rules window
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (500 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        
        //refresh rules (window)
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]).rulesWindowController loadRules];
        
    });
    
    return;
}

//init/show touch bar
-(void)initTouchBar
{
    //touch bar items
    NSArray *touchBarItems = nil;
    
    //touch bar API is only 10.12.2+
    if(@available(macOS 10.12.2, *))
    {
        //alloc/init
        self.touchBar = [[NSTouchBar alloc] init];
        if(nil == self.touchBar)
        {
            //no touch bar?
            goto bail;
        }
        
        //set delegate
        self.touchBar.delegate = self;
        
        //set id
        self.touchBar.customizationIdentifier = @"com.objective-see.blockblock";
        
        //init items
        touchBarItems = @[@".icon", @".label", @".block", @".allow"];
        
        //set items
        self.touchBar.defaultItemIdentifiers = touchBarItems;
        
        //set customization items
        self.touchBar.customizationAllowedItemIdentifiers = touchBarItems;
        
        //activate so touchbar shows up
        [NSApp activateIgnoringOtherApps:YES];
    }
    
bail:
    
    return;
}

//delegate method
// init item for touch bar
-(NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier
{
    //icon view
    NSImageView *iconView = nil;
    
    //icon
    NSImage* icon = nil;
    
    //item
    NSCustomTouchBarItem *touchBarItem = nil;
    
    //init item
    touchBarItem = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
    
    //icon
    if(YES == [identifier isEqualToString: @".icon" ])
    {
        //init icon view
        iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 30.0, 30.0)];
        
        //enable layer
        [iconView setWantsLayer:YES];
        
        //set color
        [iconView.layer setBackgroundColor:[[NSColor windowBackgroundColor] CGColor]];
        
        //mask
        iconView.layer.masksToBounds = YES;
        
        //round corners
        iconView.layer.cornerRadius = 3.0;
        
        //load icon image
        icon = [NSImage imageNamed:@"Icon"];
        
        //set size
        icon.size = CGSizeMake(30, 30);
        
        //add image
        iconView.image = icon;
        
        //set view
        touchBarItem.view = iconView;
    }
    
    //label
    else if(YES == [identifier isEqualToString:@".label"])
    {
        //item label
        touchBarItem.view = [NSTextField labelWithString:[NSString stringWithFormat:@"%@ %@", self.processSummary.stringValue,self.alertMessage.stringValue]];
    }
    
    //block button
    else if(YES == [identifier isEqualToString:@".block"])
    {
        //init button
        touchBarItem.view = [NSButton buttonWithTitle: @"Block" target:self action: @selector(handleUserResponse:)];
        
        //set tag
        // 0: block
        ((NSButton*)touchBarItem.view).tag = 0;
    }
    
    //allow button
    else if(YES == [identifier isEqualToString:@".allow"])
    {
        //init button
        touchBarItem.view = [NSButton buttonWithTitle: @"Allow" target:self action: @selector(handleUserResponse:)];
        
        //set tag
        // 1: allow
        ((NSButton*)touchBarItem.view).tag = 1;
    }
    
    return touchBarItem;
}

@end
