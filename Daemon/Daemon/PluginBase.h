//
//  PluginBase.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//


@class Event;

#import "FileMonitor.h"
#import <Foundation/Foundation.h>

@interface PluginBase : NSObject
{
    //iVars
    
    //paths to watch
    NSMutableArray* watchPaths;

    //msg to display
    NSString* alertMsg;
    
    //description
    NSString* description;
    
    //type
    // file, command, browser ext
    NSUInteger type;
    
    //flag to ignore things under top level dir
    //BOOL ignoreKids;

}

//compiled regexes
@property(retain, nonatomic)NSMutableArray* regexes;

@property BOOL ignoreKids;
@property NSUInteger type;
@property(retain, nonatomic)NSString* description;
@property(retain, nonatomic)NSString* alertMsg;


//METHODS

//init method
-(id)initWithParams:(NSDictionary*)watchItemInfo;

//new user connected
-(void)newUser:(NSString*)user;

//is match
-(BOOL)isMatch:(File*)file;

//process an event
// extra processing to decide if an alert should be shown
-(BOOL)shouldIgnore:(id)object;

//block an event
// delete binary, files (plist), etc
-(BOOL)block:(Event*)event;

//allow an event
// maybe update the original (saved) file?
-(void)allow:(Event*)event;

//take snapshot
-(void)snapshot:(NSString*)path;

//alert message
-(NSString*)alertMessage:(Event*)event;

//extract name of startup item
// i.e. name of launch item's binary
-(NSString*)itemName:(Event*)event;

//extract binary for of startup item
// i.e. launch item's binary path, or crobjob cmd
-(NSString*)itemObject:(Event*)event;

@end
