//
//  Item.m
//  Daemon
//
//  Created by Patrick Wardle on 12/18/19.
//  Copyright © 2019 Objective-See. All rights reserved.
//

#import "Item.h"
#import "PluginBase.h"

@implementation Item
    
@synthesize name;
@synthesize object;
//@synthesize type;

//init
-(id)init:(Event*)event
{
    self = [super init];
    if(self)
    {
        //set name
        self.name = [event.plugin itemName:event];
        
        //set item
        self.object = [event.plugin itemObject:event];
    }
    
    return self;
}

//for pretty print
-(NSString *)description {
    return [NSString stringWithFormat: @"name=%@, object=%@", self.name, self.object];
}

@end
