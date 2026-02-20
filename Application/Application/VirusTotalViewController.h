//
//  file: VirusTotalViewController.h
//  project: BlockBlock (login item)
//  description: view controller for VirusTotal results popup (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;
@import OSLog;

#import "HyperlinkTextField.h"


@interface VirusTotalViewController : NSViewController <NSPopoverDelegate>
{
    
}

/* METHODS */

/* PROPERTIES */

@property (weak) IBOutlet HyperlinkTextField* instigator;
@property (weak) IBOutlet HyperlinkTextField *startupItem;

@end
