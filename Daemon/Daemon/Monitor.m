//
//  Monitor.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Monitor.h"

#import "Rule.h"
#import "Event.h"
#import "Rules.h"
#import "Events.h"
#import "Utilities.h"
#import "PluginBase.h"
#import "Preferences.h"

#import "Processes.h"

/* GLOBALS */

//global rules obj
extern Rules* rules;

//global event obj
extern Events* events;

//glboal prefs obj
extern Preferences* preferences;

@implementation Monitor

@synthesize plugins;
@synthesize fileMon;
@synthesize lastEvent;
@synthesize btmMonitor;
@synthesize userObserver;
@synthesize endpointProcessClient;

//init function
-(id)init
{
    //new user
    __block NSString* newUser = nil;
    
    //init super
    self = [super init];
    if(nil != self)
    {
        //init plugin array
        plugins = [NSMutableArray array];
    }
    
    //register listener for new client/user
    // when it fires, call into each plugin in case they care...
    self.userObserver = [[NSNotificationCenter defaultCenter] addObserverForName:USER_NOTIFICATION object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
    {
        //dbg msg
        newUser = getConsoleUser();
        
        //alert each plugn
        for(PluginBase* plugin in self.plugins)
        {
            //alert plugin
            [plugin newUser:newUser];
        }
    }];
    
    return self;
}

//load watch list and enable watches
-(BOOL)start
{
    //flag
    BOOL started = NO;
    
    //events of interest for file monitor
    // also pass in process exec/exit to capture args
    es_event_type_t events[] = {ES_EVENT_TYPE_NOTIFY_CREATE, ES_EVENT_TYPE_NOTIFY_WRITE, ES_EVENT_TYPE_NOTIFY_RENAME, ES_EVENT_TYPE_NOTIFY_EXEC, ES_EVENT_TYPE_NOTIFY_EXIT};
    
    //define block for file monitor
    // automatically invoked upon file events
    FileCallbackBlock block = ^(File* file)
    {
        @autoreleasepool
        {
            //process file event
            // match alert, etc...
            [self processEvent:file plugin:nil message:nil];
        }
    };
    
    //load watch list
    // also inits all plugins objects
    if(YES != [self loadWatchList])
    {
        //err msg
        logMsg(LOG_ERR, @"'loadWatchList' method failed");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"starting file monitor...");
    
    //init monitor
    fileMon = [[FileMonitor alloc] init];

    //start monitoring
    // pass in block for events
    started = [self.fileMon start:events count:sizeof(events)/sizeof(events[0]) csOption:csNone callback:block];
    if(YES != started)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to start file monitor");
        
        //bail
        goto bail;
    }
    
    //alloc
    self.processMonitor = [[ProcessMonitor alloc] init];
    
    //start process monitor
    if(YES != [self.processMonitor start: [self findPluginByName:@"Process"]])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to start process monitor");
        
        //bail
        goto bail;
    }
    
    //macOS 14+
    // can use BTM events
    if(@available(macOS 14, *))
    {
        //alloc
        self.btmMonitor = [[BTMMonitor alloc] init];
        
        //start
        if(YES != [self.btmMonitor start:[self findPluginByName:@"Btm"]])
        {
            //err msg
            logMsg(LOG_ERR, @"failed to start btm monitor");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"started btm monitor");
    }
    
    //happy
    started = YES;
    
bail:

    return started;
}


//stop monitors
-(BOOL)stop
{
    //flag
    BOOL stopped = NO;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"stopping file monitor...");
    
    //stop
    if(YES != [self.fileMon stop])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to stop file monitor");
        
        //bail
        goto bail;
    }
    
    //unset
    self.fileMon = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"stopped file monitor");
    
    //dbg msg
    logMsg(LOG_DEBUG, @"stopping process monitor...");
    
    //stop process monitor
    if(YES != [self.processMonitor stop])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to stop process monitor");
        
        //bail
        goto bail;
    }
    
    //unset
    self.processMonitor = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"stopped process monitor");
    
    //stop BTM monitor
    if(nil != self.btmMonitor)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"stopping btm monitor...");
        
        //stop
        [self.btmMonitor stop];
        
        //unset
        self.btmMonitor = nil;
        
        //dbg msg
        logMsg(LOG_DEBUG, @"stopped btm monitor");
    }
    
    //happy
    stopped = YES;
    
bail:

    return stopped;
}

//process an event
// a) determine if it's an event of interest
// b) then, build and deliver alert to the user
-(void)processEvent:(File*)file plugin:(PluginBase*)plugin message:(es_message_t*)message
{
    //flag
    BOOL wasDelivered = NO;
    
    //event
    Event* event = nil;
    
    //matching rule (if any)
    Rule* matchingRule = nil;
    
    //plugin
    PluginBase* matchingPlugin = nil;
    
    //skip if event was caused by self
    // e.g. blocking an item by editing a watched file
    if(getpid() == file.process.pid)
    {
        //bail
        goto bail;
    }
    
    //skip events with empty destination path
    if(0 == file.destinationPath.length)
    {
        //bail
        goto bail;
    }

    //plugin provided?
    if(nil != plugin)
    {
        //save
        matchingPlugin = plugin;
    }
    //otherwise find plugin
    // ...that cares about the path/file that was just created
    else
    {
        //find
        matchingPlugin = [self findPlugin:file];
        if(nil == matchingPlugin)
        {
            //bail
            goto bail;
        }
    }

    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found plugin %@ for %@", matchingPlugin, file]);
    
    //allow the plugin to closely examine the event
    // it will know more about the details so can determine if it should be ignored
    if(YES == [matchingPlugin shouldIgnore:file])
    {
        //ignore
        goto bail;
    }
    
    //create event
    event = [Event alloc];
        
    //add message
    if(nil != message)
    {
        //add msg
        event.esMessage = message;
    }
    
    //complete initialization
    event = [event init:file plugin:matchingPlugin];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"created event: %@", event]);
    
    //any matching rules?
    // do this here, since we need an event and plugin obj
    matchingRule = [rules find:event];
    if(nil != matchingRule)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found matching rule %@ for %@", matchingRule, file]);
        
        //rule: allow
        if(ALLOW_EVENT == matchingRule.action)
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"matching rule says, 'allow' ...so allowing!");
        }
        //rule: block
        else
        {
            //dbg/log msg
            logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"matching rule says, 'block', so blocking %@", event]);
            
            //block
            if(YES != [matchingPlugin block:event])
            {
                //err msg
                logMsg(LOG_ERR, @"failed to block event!");
            }
        }
    
        //done!
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"no matching rule found...");
    
    //passive mode?
    // no rule, just allow (but log)
    if(YES == [preferences.preferences[PREF_PASSIVE_MODE] boolValue])
    {
        //dbg/log msg
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"client in passive mode, so allowing %@", event]);
    
        //done!
        goto bail;
    }
        
    //matches last event?
    // if so, ignore the event
    if(YES == [event isRelated:self.lastEvent])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"matches last event, so ignoring");
        
        //update
        self.lastEvent = event;
        
        //skip
        goto bail;
    }
    
    //update
    self.lastEvent = event;
    
    //ignore (closely) matched alerts
    // ...that were already shown to user
    if(YES == [events wasShown:event])
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"event %@ matches/is related to a shown alert, so ignoring", event]);
        
        //skip
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"event appears to be new!, will deliver");
    
    //deliver alert
    // can fail if no client
    if(YES == [events deliver:event])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"alert delivered...");
        
        //set flag
        wasDelivered = YES;
    }
    
bail:
    
    //not delivered?
    // free es message
    if( (YES != wasDelivered) &&
        (nil != event.esMessage) )
    {
        es_free_message(event.esMessage);
        event.esMessage = NULL;
    }

    return;
}
 
//load list of plugins/watch paths
// for each plugin, instantiate a plugin object
-(BOOL)loadWatchList
{
    //return var
    BOOL bRet = NO;
    
    //path to watch list
    // plist w/ all plugins/info
    NSString* watchListPath = nil;
    
    //(per plugin) items
    NSArray* watchList = nil;
    
    //plugin obj
    PluginBase* plugin = nil;
    
    //plugin min OS
    NSNumber* pluginMinOS = 0;
    
    //plugin max OS
    NSNumber* pluginMaxOS = 0;
    
    //get path to watch list
    watchListPath = [[NSBundle mainBundle] pathForResource:@"watchList" ofType:@"plist"];
    if(nil == watchListPath)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to load watch list");
        
        //bail
        goto bail;
    }
    
    //load watch list
    watchList = [[NSMutableArray alloc] initWithContentsOfFile:watchListPath];
    if(nil == watchList)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to load watch list from %@", watchListPath]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"watchlist: %@", watchList]);
    
    //iterate over all watch items
    // instantiate a plugin for each
    for(NSDictionary* watchItem in watchList)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"watch item: %@/%@", watchItem, NSClassFromString(watchItem[@"class"])]);
        
        //grab min/max supported OS
        pluginMinOS = watchItem[@"minOSVersion"];
        pluginMaxOS = watchItem[@"maxOSVersion"];
        
        //check:
        // is system's OS version new enough to support plugin?
        if( (nil != pluginMinOS) &&
            (pluginMinOS.unsignedIntValue < NSProcessInfo.processInfo.operatingSystemVersion.majorVersion) )
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"macOS %ld too old for plugin %@ (min: %@)", (long)NSProcessInfo.processInfo.operatingSystemVersion.majorVersion, watchItem[@"class"], pluginMinOS]);
            
            //skip this plugin
            continue;
        }
        
        //check
        // is system's OS version too new to support plugin?
        if( (nil != pluginMaxOS) &&
            (pluginMaxOS.unsignedIntValue < NSProcessInfo.processInfo.operatingSystemVersion.majorVersion) )
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"macOS %ld too new for plugin %@ (max: %@)", (long)NSProcessInfo.processInfo.operatingSystemVersion.majorVersion, watchItem[@"class"], pluginMaxOS]);
            
            //skip this plugin
            continue;
        }
        
        //init plugin
        // will also init paths
        plugin = [(PluginBase*)([NSClassFromString(watchItem[@"class"]) alloc]) initWithParams:watchItem];
        if(nil == plugin)
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to initialize plugin: %@", watchItem[@"class"]]);
            
            //skip
            continue;
        }
        
        //save plugin
        [self.plugins addObject:plugin];
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"registered plugins: %@", self.plugins]);

    //no errors
    bRet = YES;
    
bail:
    
    return bRet;
}


//find loaded plugin by name
-(PluginBase*)findPluginByName:(NSString*)name
{
    //plugin
    __block PluginBase* plugin = nil;
    
    //look for plugin that can handle path
    [plugins enumerateObjectsUsingBlock:^(PluginBase* currentPlugin, NSUInteger index, BOOL* stop)
    {
        //is match?
        if(NSOrderedSame == [currentPlugin.className caseInsensitiveCompare:name])
        {
            //save
            plugin = currentPlugin;
            
            //stop
            *stop = YES;
        }
    }];
    
    return plugin;
    
}

//find the plugin (or none) that's intersted in the path
-(PluginBase*)findPlugin:(File*)file
{
    //plugin
    __block PluginBase* plugin = nil;
    
    //look for plugin that can handle path
    [plugins enumerateObjectsUsingBlock:^(PluginBase* currentPlugin, NSUInteger index, BOOL* stop)
    {
        //is match?
        if(YES == [currentPlugin isMatch:file])
        {
            //save
            plugin = currentPlugin;
            
            //stop
            *stop = YES;
        }
    }];
    
    return plugin;
}

@end
