//
//  file: VirusTotalViewController.h
//  project: BlockBlock (login item)
//  description: view controller for VirusTotal results popup (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "logging.h"
#import "utilities.h"
#import "VirusTotal.h"
#import "VirusTotalViewController.h"

@implementation VirusTotalViewController

@synthesize message;
@synthesize vtSpinner;

//automatically invoked
// configure popover and kick off VT queries
-(void)popoverWillShow:(NSNotification *)notification;
{
    //set message
    self.message.stringValue = @"querying virus total...";
    
    //bg thread for VT
    [self performSelectorInBackground:@selector(queryVT) withObject:nil];
    
    return;
}

//automatically invoked
// finish configuring popover
-(void)popoverDidShow:(NSNotification *)notification
{
    //show spinner
    self.vtSpinner.hidden = NO;
    
    //start
    [self.vtSpinner startAnimation:nil];
    
    //make the animation show...
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    
    return;
}

//make a query to VT in the background
// invokes helper function to update UI as needed (results/errors)
-(void)queryVT
{
    //vt object
    VirusTotal* vtObj = nil;
    
    //hash
    NSString* hash = nil;
    
    //item
    NSMutableDictionary* item = nil;
    
    //alloc
    vtObj = [[VirusTotal alloc] init];
    
    //alloc
    item = [NSMutableDictionary dictionary];
    
    //nap to allow msg/spinner to do a bit
    [NSThread sleepForTimeInterval:1.0f];
    
    //hash
    hash = hashFile(self.itemPath);
    if(0 == hash.length)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to hash %@ to submit", self.itemName]);
        
        //show error on main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //show error
            [self showError];
            
        });
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"querying VT with %@", self.itemPath]);
    
    //add name
    item[@"name"] = self.itemName;
    
    //add path
    item[@"path"] = self.itemPath;
    
    //add hash
    item[@"hash"] = hash;
    
    //query VT
    // ->also check for error (offline, etc)
    if(YES == [vtObj queryVT:item])
    {
        //modal window, so use 'performSelectorOnMainThread' to update
        [self performSelectorOnMainThread:@selector(displayResults:) withObject:item waitUntilDone:YES];
    }
    
    //error
    else
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to query virus total: %@", item]);
        
        //modal window, so use 'performSelectorOnMainThread' to update
        [self performSelectorOnMainThread:@selector(showError) withObject:nil waitUntilDone:YES];
    }

bail:
    
    return;
}

//display results
-(void)displayResults:(NSMutableDictionary*)item
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"VT response: %@", item]);
    
    //stop spinner
    [self.vtSpinner stopAnimation:nil];
    
    //hide spinner
    self.vtSpinner.hidden = YES;
    
    //editable (for link)
    self.message.allowsEditingTextAttributes = YES;
    
    //selectable (for link)
    self.message.selectable = YES;
    
    //format response
    // updates self.message
    [self formatVTInfo:item];
    
    return;
}

//show error in UI
-(void)showError
{
    //stop spinner
    [self.vtSpinner stopAnimation:nil];
    
    //hide spinner
    self.vtSpinner.hidden = YES;
    
    //set message
    self.message.stringValue = @"failed to query virus total :(";
    
    return;
}

//set's string with process/binary name + signing info
// extra logic need to make a clickable link for VT report
-(void)formatVTInfo:(NSDictionary*)item
{
    //info
    NSMutableString* info = nil;
    
    //name
    // handles truncations, etc
    NSString* name = nil;
    
    //coverted color
    NSColor *convertedColor = nil;
    
    //hex color
    NSString* hexColor = nil;
    
    //html code
    NSString* html = nil;
    
    //init string
    info = [[NSMutableString alloc] initWithString:@""];
    
    //grab name
    name = item[@"name"];
    
    //truncate long names
    if(name.length > 25)
    {
        //truncate
        name = [[name substringToIndex:22] stringByAppendingString:@"..."];
    }
    
    //add name
    [info appendFormat:@"%@: ", name];
    
    //sanity check
    if( (nil == item[@"vtInfo"]) ||
        (nil == item[@"vtInfo"][@"found"]) )
    {
        //set
        [info appendString:@"received invalid response"];
        
        //add
        self.message.stringValue = info;
        
        //bail
        goto bail;
    }

    //add ratio and report link if file is found
    if(0 != [item[@"vtInfo"][@"found"] intValue])
    {
        //sanity check
        if( (nil == item[@"vtInfo"][@"detection_ratio"]) ||
            (nil == item[@"vtInfo"][@"permalink"]) )
        {
            //set
            [info appendString:@"received invalid response"];
            
            //add
            self.message.stringValue = info;
            
            //bail
            goto bail;
        }
        
        /*
        //make ratio red if there are positives
        if( (nil != item[@"vtInfo"][@"positives"]) &&
            (0 != [item[@"vtInfo"][@"positives"] intValue]) )
        {
            //red
            //attributes = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:13], NSForegroundColorAttributeName:[NSColor systemRedColor]};
        }
        */
        
        //add ratio
        [info appendFormat:@" %@", item[@"vtInfo"][@"detection_ratio"]];
        
        //convert color
        convertedColor = [self.message.textColor colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
        
        //hexify for html
        hexColor = [NSString stringWithFormat:@"%02X%02X%02X", (int) (convertedColor.redComponent * 0xFF), (int) (convertedColor.greenComponent * 0xFF), (int) (convertedColor.blueComponent * 0xFF)];
        
        //create html
        html = [NSString stringWithFormat:@"<span style=\"font-family:'%@'; font-size:%dpx; color:%@\">%@<br><center><a href=\"%@\">Full Details</a></center></span>", self.message.font.fontName, (int)self.message.font.pointSize, hexColor, info, item[@"vtInfo"][@"permalink"]];
        
        //set message
        // note: attribute string
        self.message.attributedStringValue = [[NSAttributedString alloc] initWithHTML:[html dataUsingEncoding:NSUTF8StringEncoding] documentAttributes:nil];
        
    }
    //file not found on vt
    else
    {
        //add ratio
        [info appendString:@"not found"];
        
        //add
        self.message.stringValue = info;
    }
    
bail:

    return;
}

@end
