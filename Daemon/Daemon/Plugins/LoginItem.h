//
//  LoginItem.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "../PluginBase.h"

//TODO: maybe move this into watch path
//path to login items
#define LOGIN_ITEMS @"~/Library/Application Support/com.apple.backgroundtaskmanagementagent/backgrounditems.btm"

#define LOGIN_ITEM_NAME @"itemName"
#define LOGIN_ITEM_PATH @"itemPath"

@interface LoginItem : PluginBase
{
    
}

/* PROPERTIES */

//orginal login items
@property(nonatomic, retain)NSMutableDictionary* originals;


/* METHODS */

//update originals
// ensures there is always the latest version of the login items saved
-(void)updateOriginals:(NSString*)path;

//TODO:
//find's latest login item
// ->diff's original list of login items with current ones
//-(NSDictionary*)findLoginItem:(WatchEvent*)watchEvent;

//update the global originals list with contents of login item file
//-(void)updateOriginals:(NSString*)path;

@end
