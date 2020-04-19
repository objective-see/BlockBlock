//
//  LoginItem.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "../PluginBase.h"

//path to login items
// used to build path for each user
#define LOGIN_ITEMS @"Library/Application Support/com.apple.backgroundtaskmanagementagent/backgrounditems.btm"

#define LOGIN_ITEM_NAME @"itemName"
#define LOGIN_ITEM_PATH @"itemPath"

@interface LoginItem : PluginBase
{
    
}

/* PROPERTIES */

//orginal login items
@property(nonatomic, retain)NSMutableDictionary* snapshot;

/* METHODS */

//take snapshot
// ensures there is always the latest version of the login items
-(void)snapshot:(NSString*)path;

@end
