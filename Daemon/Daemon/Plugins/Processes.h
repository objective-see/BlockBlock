//
//  Process.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

@import Foundation;
#import "../PluginBase.h"

@interface Processes : PluginBase

/* PROPERTIES */

//array of scripts
@property(nonatomic, retain)NSArray* scripts;

//last process event
@property(nonatomic, retain)Process* lastScript;

@end
