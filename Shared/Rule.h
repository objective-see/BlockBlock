//
//  file: Rule.h
//  project: BlockBlock (shared)
//  description: Rule object (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef Rule_h
#define Rule_h

#ifdef DAEMON_BUILD

#import "Item.h"
#import "Event.h"

#endif

#import <Foundation/Foundation.h>


@interface Rule : NSObject <NSSecureCoding>
{
    
}

/* PROPERTIES */


// PROCESS INFO

//process path
@property(nonatomic, retain)NSString* processPath;

//process name
@property(nonatomic, retain)NSString* processName;

//process cs flags
@property(nonatomic, retain)NSNumber* processCSFlags;

//process signing ID
@property(nonatomic, retain)NSString* processSigningID;

// STARTUP ITEM INFO

//item file
@property(nonatomic, retain)NSString* itemFile;

//item object (binary, cmd, etc)
@property(nonatomic, retain)NSString* itemObject;

// ACTION

// allow / deny
@property NSUInteger action;

// scope
@property NSInteger scope;

/* METHODS */

#ifdef DAEMON_BUILD

//init method
-(id)init:(Event*)event;

#endif

@end


#endif /* Rule_h */
