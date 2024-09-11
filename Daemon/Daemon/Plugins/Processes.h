//
//  Process.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

@import OSLog;
@import Foundation;

#import "../PluginBase.h"

@interface Processes : PluginBase

/* PROPERTIES */

//last process event
@property(nonatomic, retain)Process* lastScript;

@end
