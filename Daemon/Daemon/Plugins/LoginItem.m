//
//  LoginItem.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Item.h"
#import "Event.h"
#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "LoginItem.h"
#import "XPCUserClient.h"

//user client
extern XPCUserClient* xpcUserClient;

// REGEX
// ^(\/Users\/.+|)\/Library\/Application Support\/com.apple.backgroundtaskmanagementagent\/backgrounditems.btm$
// breakdown:
// ^ -> starts with
// (\/Users\/.+) -> "/Users/<blah>"
// ...then just /Library/Application Support/com.apple.backgroundtaskmanagementagent/backgrounditems.btm

// path: ~/Library/Application Support/com.apple.backgroundtaskmanagementagent/backgrounditems.btm

@implementation LoginItem

@synthesize originals;

//init
-(id)initWithParams:(NSDictionary*)watchItemInfo
{
    //init super
    self = [super initWithParams:watchItemInfo];
    if(nil != self)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"init'ing %@ (%p)", NSStringFromClass([self class]), self]);
        #endif
        
        //set type
        self.type = PLUGIN_TYPE_LOGIN_ITEM;
        
        //alloc dictionary for originals
        originals = [NSMutableDictionary dictionary];
        
    }

    return self;
}

//new user connected
// update the list of their login items
-(void)newUser:(NSString *)user
{
    //update list of login items
    [self updateOriginals:[LOGIN_ITEMS stringByReplacingOccurrencesOfString:@"~" withString:NSHomeDirectoryForUser(user)]];
    
    return;
}

//get the name of the launch item
-(NSString*)itemName:(Event*)event
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"'%s' invoked", __PRETTY_FUNCTION__]);
    
    return [self findLoginItem:event.file][LOGIN_ITEM_NAME];
}

//get the binary (path) of the launch item
-(NSString*)itemObject:(Event*)event
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"'%s' invoked", __PRETTY_FUNCTION__]);
    
    return [self findLoginItem:event.file][LOGIN_ITEM_PATH];
}

//check login items file
// was a new item added?
-(BOOL)shouldIgnore:(File*)file
{
    //flag
    // default to ignore
    BOOL shouldIgnore = YES;
 
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"'%s' invoked", __PRETTY_FUNCTION__]);
    
    //only care about new login items
    // might be another file edits which are ok to ignore...
    if(nil != [self findLoginItem:file])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"found new login item, so NOT IGNORING");
    
        //don't ignore
        shouldIgnore = NO;
    }
    
    //if ignoring
    // still update originals
    if(YES == shouldIgnore)
    {
        //update
        [self updateOriginals:file.destinationPath];
    }
    
    return shouldIgnore;
}

//update originals
// ensures there is always the latest version of the login items saved
-(void)updateOriginals:(NSString*)path
{
    //plist data
    NSDictionary* plistData = nil;
    
    //login items
    NSDictionary* loginItems = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"updating orginals of user's login items at: %@", path]);
    
    //sanity check
    if(0 == path.length) goto bail;
    
    //load login items
    plistData = [NSDictionary dictionaryWithContentsOfFile:path];
    if(0 == plistData.count) goto bail;
    
    //extract
    loginItems = [self extractFromBookmark:plistData];
    if(nil == loginItems) goto bail;
    
    //save `em
    self.originals[path] = loginItems;

bail:

    return;
}

//invoked when user clicks 'allow'
-(void)allow:(Event *)event
{
    //just update originals
    [self updateOriginals:event.file.destinationPath];
    
    return;
}

//extract login items from bookmark data
// newer versions of macOS use this format...
-(NSMutableDictionary*)extractFromBookmark:(NSDictionary*)data
{
    //login items
    NSMutableDictionary* loginItems = nil;
    
    //init
    loginItems = [NSMutableDictionary dictionary];
    
    //bookmark data
    NSData* bookmark = nil;
    
    //bookmark properties
    NSDictionary* properties = nil;
    
    //name
    NSString* name = nil;
    
    //path
    NSString* path = nil;
    
    //extract current login items
    for(id object in data[@"$objects"])
    {
        //reset
        bookmark = nil;
        
        //straight data?
        if(YES == [object isKindOfClass:[NSData class]])
        {
            //assign
            bookmark = object;
        }
        
        //dictionary w/ data?
        if(YES == [object isKindOfClass:[NSDictionary class]])
        {
            //extract bookmark data
            bookmark = [object objectForKey:@"NS.data"];
        }
        
        //no data?
        if(nil == bookmark)
        {
            //skip
            continue;
        }
        
        //extact properties
        // 'resourceValuesForKeys' returns a dictionary, but we want the 'NSURLBookmarkAllPropertiesKey' dictionary inside that
        properties = [NSURL resourceValuesForKeys:@[@"NSURLBookmarkAllPropertiesKey"] fromBookmarkData:bookmark][@"NSURLBookmarkAllPropertiesKey"];
        if(nil == properties)
        {
            //skip
            continue;
        }
        
        //dbg msg
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"bookmark props: %@", properties]);
    
        //extract path
        path = properties[@"_NSURLPathKey"];
        
        //use name from app bundle
        // otherwise from 'NSURLNameKey'
        name = [NSBundle bundleWithPath:path].infoDictionary[@"CFBundleName"];
        if(0 == name.length)
        {
            //extract name
            name = properties[@"NSURLNameKey"];
        }
        
        //skip any issues
        if( (nil == name) ||
            (nil == path) )
        {
            //skip
            continue;
        }
        
        //add
        // key: path
        // value: name
        loginItems[path] = name;
    }
    
    return loginItems;
}

//find's latest login item
// diff's original list of login items with current ones
-(NSDictionary*)findLoginItem:(File*)file
{
    //latest login item
    NSDictionary* loginItem = nil;
    
    //plist data
    NSDictionary* plistData = nil;
    
    //current login items
    NSMutableDictionary* currentLoginItems = nil;
    
    //original login items
    NSMutableDictionary* originalLoginItems = nil;
    
    //set of new login items
    NSMutableSet *newLoginItems = nil;
    
    //path of new login item
    NSString* path = nil;
    
    //name of new login item
    NSString* name = nil;
    
    //grab original login items
    originalLoginItems = self.originals[file.destinationPath];
    
    //load login items
    plistData = [NSDictionary dictionaryWithContentsOfFile:file.destinationPath];
    if(0 == plistData.count) goto bail;
    
    //extract (current) login items
    currentLoginItems = [self extractFromBookmark:plistData];
    if(0 == currentLoginItems.count) goto bail;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"current login items: %@", currentLoginItems]);
    
    //init set of new login items with current login items
    newLoginItems = [NSMutableSet setWithArray:[currentLoginItems allKeys]];
    
    //subtract out original ones
    [newLoginItems minusSet:[NSMutableSet setWithArray:[originalLoginItems allKeys]]];
    if(0 == newLoginItems.count) goto bail;

    //path
    // grab last item
    path = [[newLoginItems allObjects] lastObject];
    
    //name
    name = currentLoginItems[path];
    
    //check & init
    if( (nil != name) &&
        (nil != path) )
    {
        //init
        loginItem = @{LOGIN_ITEM_NAME:name, LOGIN_ITEM_PATH:path};
    }

bail:
    
    return loginItem;
}

//block login item
// gotta call into user session, as login items are context specific :/
-(BOOL)block:(Event*)event;
{
    //return/status var
    __block BOOL wasBlocked = NO;
    
    //wait semaphore
    dispatch_semaphore_t semaphore = 0;
    
    //init sema
    semaphore = dispatch_semaphore_create(0);
    
    //define block
    void(^block)(NSNumber *) = ^(NSNumber *result)
    {
        //save result
        wasBlocked = (BOOL)(result.intValue == 0);
        
        //signal sema
        dispatch_semaphore_signal(semaphore);
    };
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"'%s' invoked", __PRETTY_FUNCTION__]);
    
    //remove login item
    // gotta call into user session to remove
    [xpcUserClient removeLoginItem:[NSURL fileURLWithPath:event.item.object] reply:block];
    
    //wait for installer logic to be completed by XPC
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    return wasBlocked;
}

@end
