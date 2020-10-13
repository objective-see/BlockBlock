//
//  file: Rules.h
//  project: BlockBlock (launch daemon)
//  description: handles rules & actions such as add/delete (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


#ifndef Rules_h
#define Rules_h

#import "XPCUserClient.h"

@import Foundation;

@class Rule;


@interface Rules : NSObject
{
    
}

/* PROPERTIES */

//rules
@property(nonatomic, retain)NSMutableDictionary* rules;


/* METHODS */

//load from disk
-(BOOL)load;

//add a rule
-(BOOL)add:(Event*)event;

//find (matching) rule
-(Rule*)find:(Event*)event;

//delete rule
// args: process path, item (path)
-(BOOL)delete:(Rule*)rule;

@end


#endif /* Rules_h */
