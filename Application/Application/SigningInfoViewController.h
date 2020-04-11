//
//  file: SigningInfoViewController
//  project: BlockBlock (login item)
//  description: view controller for signing info popup (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;

/* DEFINES */

//views
#define CS_FLAGS_VIEW           1
#define PLATFORM_BINARY_VIEW    2
#define TEAM_ID_VIEW            3
#define SIGNING_ID_VIEW         4

@interface SigningInfoViewController : NSViewController <NSPopoverDelegate>
{
    
}

/* METHODS */


/* PROPERTIES */

//alert info
@property(nonatomic, retain)NSDictionary* alert;

//signing icon
@property (weak) IBOutlet NSImageView* icon;

//main signing msg
@property (weak) IBOutlet NSTextField* message;

//details
//@property (weak) IBOutlet NSTextField* details;

//no signing auths
//@property (weak) IBOutlet NSTextField *noSigningAuths;

@end
