//
//  PluginBase.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Event.h"
#import "PluginBase.h"


#define kErrFormat @"%@ not implemented in subclass %@"
#define kExceptName @"BB Plugin"

@implementation PluginBase

@synthesize type;
@synthesize regexes;
@synthesize alertMsg;
@synthesize ignoreKids;
@synthesize description;

//init
-(id)initWithParams:(NSDictionary*)watchItemInfo
{
    //super
    self = [super init];
    
    if(nil != self)
    {
        //alloc
        regexes = [NSMutableArray array];
        
        //compile and add each regex
        for(NSString* regex in watchItemInfo[@"paths"])
        {
            NSRegularExpression* compiledRegex = nil;
            
            //compile
            compiledRegex = [NSRegularExpression regularExpressionWithPattern:regex options:NSRegularExpressionCaseInsensitive error:NULL];
            if(nil == compiledRegex)
            {
                //skip
                continue;
            }
            
            //add
            [self.regexes addObject:compiledRegex];
        }
        
        //save description from plugin's .plist
        self.description = watchItemInfo[@"description"];
        
        //save alert msg from plugin's .plist
        self.alertMsg = watchItemInfo[@"alert"];
        
        //save flag about match level
        self.ignoreKids = [watchItemInfo[@"ignoreKids"] boolValue];
        
    }
    
    return self;
}

//is a file a match?
-(BOOL)isMatch:(File*)file
{
    //flag
    __block BOOL matched = NO;
    
    //path
    NSString* path = nil;
    
    //extract path
    path = file.destinationPath;
    
    //match?
    [self.regexes enumerateObjectsUsingBlock:^(NSRegularExpression* regex, NSUInteger index, BOOL * _Nonnull stop) {
        
        //match
        NSTextCheckingResult* match = nil;
        
        //is match?
        match = [regex firstMatchInString:path options:0 range:NSMakeRange(0, path.length)];
        if( (nil == match) ||
            (NSNotFound == match.range.location) )
        {
            //no match
            // keep checking
            return;
        }
        
        //got match
        matched = YES;
            
        //done
        *stop = YES;
        
    }];
    
    return matched;
}


/* OPTIONAL METHODS */

//stubs for inherited methods
// these aren't required, so will just return here if not invoked in child classes

//new user connected
-(void)newUser:(NSString*)user
{
    return;
}

//callback when watch event is allowed
-(void)allow:(Event *)event
{
    return;
}

//give plugin the option to (more) closely examine event
-(BOOL)shouldIgnore:(id)object
{
    return NO;
}

//take snapshot
-(void)snapshot:(NSString*)path
{
    return;
}

//alert message
// returns default msg
-(NSString*)alertMessage:(Event*)event
{
    return self.alertMsg;
}

/* REQUIRED METHODS */

//stubs for inherited methods
// all just throw exceptions as they should be implemented in sub-classes

-(BOOL)block:(Event*)event
{
    @throw [NSException exceptionWithName:kExceptName
                                   reason:[NSString stringWithFormat:kErrFormat, NSStringFromSelector(_cmd), [self class]]
                                 userInfo:nil];
    return NO;
}

-(NSString*)itemName:(Event*)event
{
    @throw [NSException exceptionWithName:kExceptName
                                   reason:[NSString stringWithFormat:kErrFormat, NSStringFromSelector(_cmd), [self class]]
                                 userInfo:nil];
    return nil;
}

-(NSString*)itemObject:(Event*)event
{
    @throw [NSException exceptionWithName:kExceptName
                                   reason:[NSString stringWithFormat:kErrFormat, NSStringFromSelector(_cmd), [self class]]
                                 userInfo:nil];
    return nil;
}

@end
