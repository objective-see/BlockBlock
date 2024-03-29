//
//  file: Update.h
//  project: BlockBlock (shared)
//  description: checks for new versions of BlockBlock (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef Update_h
#define Update_h

@import Cocoa;
@import OSLog;
@import Foundation;

@interface Update : NSObject

//check for an update
// will invoke app delegate method to update UI when check completes
-(void)checkForUpdate:(void (^)(NSUInteger result, NSString* latestVersion))completionHandler;

@end

#endif
