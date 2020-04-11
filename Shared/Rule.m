//
//  file: Rule.h
//  project: BlockBlock (shared)
//  description: Rule object (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Rule.h"
#import "consts.h"
#import "logging.h"
#import "utilities.h"

@implementation Rule

@synthesize scope;
@synthesize action;

#ifdef DAEMON_BUILD

//init method
// with event obj
-(id)init:(Event*)event
{
    //init super
    if(self = [super init])
    {
        //init process path
        self.processPath = event.file.process.path;
        
        //init process name
        self.processName = event.file.process.name;
        
        //init process cs flags
        self.processCSFlags = event.file.process.csFlags;
        
        //init process signing info
        self.processSigningID = event.file.process.signingID;
        
        //scope is process level?
        // set file and object to '*' (any)
        if(ACTION_SCOPE_PROCESS == event.scope)
        {
            //init item file
            self.itemFile = @"*";
            
            //init item object
            self.itemObject = @"*";
        }
        //scope is file level?
        // set item to '*' (any)
        else if(ACTION_SCOPE_FILE == event.scope)
        {
            //init item file
            self.itemFile = event.file.destinationPath;
            
            //init item object
            self.itemObject = @"*";
        }
        //default is both file and item
        else
        {
            //init item file
            self.itemFile = event.file.destinationPath;
           
            //init item object
            self.itemObject = event.item.object;
        }

        //add action
        self.action = event.action;
        
        //add scope
        self.scope = event.scope;
    }
        
    return self;
}

#endif

//required as we support seecure coding
+(BOOL)supportsSecureCoding
{
    return YES;
}

//init with coder
-(id)initWithCoder:(NSCoder *)decoder
{
    //super
    if(self = [super init])
    {
        //init process info
        self.processPath = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(processPath))];
        self.processName = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(processName))];
        self.processCSFlags =  [decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(processCSFlags))];
        self.processSigningID = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(processSigningID))];

        //add item info
        self.itemFile = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(itemFile))];
        self.itemObject = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(itemObject))];

        //add scope/action
        self.scope = [decoder decodeIntegerForKey:NSStringFromSelector(@selector(scope))];
        self.action = [decoder decodeIntegerForKey:NSStringFromSelector(@selector(action))];
    }
    
    return self;
}

//encode with coder
-(void)encodeWithCoder:(NSCoder *)encoder
{
    //encode process info
    [encoder encodeObject:self.processPath forKey:NSStringFromSelector(@selector(processPath))];
    [encoder encodeObject:self.processName forKey:NSStringFromSelector(@selector(processName))];
    [encoder encodeObject:self.processCSFlags forKey:NSStringFromSelector(@selector(processCSFlags))];
    [encoder encodeObject:self.processSigningID forKey:NSStringFromSelector(@selector(processSigningID))];
    
    //encode item info
    [encoder encodeObject:self.itemFile forKey:NSStringFromSelector(@selector(itemFile))];
    [encoder encodeObject:self.itemObject forKey:NSStringFromSelector(@selector(itemObject))];
    
    //encode scope/action
    [encoder encodeInteger:self.scope forKey:NSStringFromSelector(@selector(scope))];
    [encoder encodeInteger:self.action forKey:NSStringFromSelector(@selector(action))];
    
    return;
}

//override description method
// allows rules to be 'pretty-printed'
-(NSString*)description
{
    //just serialize
    return [NSString stringWithFormat:@"RULE: process path: %@, item file: %@, item object: %@, action: %#lx, scope: %ld", self.processPath, self.itemFile, self.itemObject, (unsigned long)self.action, (long)self.scope];
}

@end
