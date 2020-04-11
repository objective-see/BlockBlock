//
//  Item.h
//  Daemon
//
//  Created by Patrick Wardle on 12/18/19.
//  Copyright © 2019 Objective-See. All rights reserved.
//

@class PluginBase;

#import "Event.h"

#import "FileMonitor.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Item : NSObject
{
    
}

/* PROPERTIES */

//type
//@property NSUInteger type;

//name
@property(nonatomic, retain)NSString* name;

//binary/cmd/etc
@property(nonatomic, retain)NSString* object;


/* METHODS */

//init
-(id)init:(Event*)event;

@end


NS_ASSUME_NONNULL_END
