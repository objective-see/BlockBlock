//
//  Monitor.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Rule.h"
#import "Event.h"
#import "Rules.h"
#import "Consts.h"
#import "Events.h"
#import "Monitor.h"
#import "Utilities.h"
#import "PluginBase.h"
#import "Preferences.h"

#import "Processes.h"

/* GLOBALS */

//global rules obj
extern Rules* rules;

//global event obj
extern Events* events;

//log handle
extern os_log_t logHandle;

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
    
    //btm plugin
    PluginBase* btmPlugin = nil;
    
    //process plugin
    PluginBase* processPlugin = nil;

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
        os_log_error(logHandle, "ERROR: 'loadWatchList' method failed");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "starting file monitor...");
    
    //init monitor
    fileMon = [[FileMonitor alloc] init];

    //start monitoring
    // pass in block for events
    started = [self.fileMon start:events count:sizeof(events)/sizeof(events[0]) csOption:csNone callback:block];
    if(YES != started)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to start file monitor");
        
        //bail
        goto bail;
    }
    
    //find process plugin
    processPlugin = [self findPluginByName:@"Processes"];
    if(nil == processPlugin)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to find process plugin");
        
        //bail
        goto bail;
    }
    
    //alloc
    self.processMonitor = [[ProcessMonitor alloc] init];
    
    //start process monitor
    if(YES != [self.processMonitor start:processPlugin])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to start process monitor");
        
        //bail
        goto bail;
    }
    
    //macOS 14+
    // can use BTM events
    if(@available(macOS 14, *))
    {
        btmPlugin = [self findPluginByName:@"Btm"];
        if(nil == btmPlugin)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to find btm plugin");
            
            //bail
            goto bail;
        }
        
        //alloc
        self.btmMonitor = [[BTMMonitor alloc] init];

        //start
        if(YES != [self.btmMonitor start:btmPlugin])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to start btm monitor");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        os_log_debug(logHandle, "started btm monitor");
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
    os_log_debug(logHandle, "stopping file monitor...");
    
    //stop
    if(YES != [self.fileMon stop])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to stop file monitor");
        
        //bail
        goto bail;
    }
    
    //unset
    self.fileMon = nil;
    
    //dbg msg
    os_log_debug(logHandle, "stopped file monitor");
    
    //dbg msg
    os_log_debug(logHandle, "stopping process monitor...");
    
    //stop process monitor
    if(YES != [self.processMonitor stop])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to stop process monitor");
        
        //bail
        goto bail;
    }
    
    //unset
    self.processMonitor = nil;
    
    //dbg msg
    os_log_debug(logHandle, "stopped process monitor");
    
    //stop BTM monitor
    if(nil != self.btmMonitor)
    {
        //dbg msg
        os_log_debug(logHandle, "stopping btm monitor...");
        
        //stop
        [self.btmMonitor stop];
        
        //unset
        self.btmMonitor = nil;
        
        //dbg msg
        os_log_debug(logHandle, "stopped btm monitor");
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
    
    //passive mode
    // ...can allow all the things
    if(YES == [preferences.preferences[PREF_PASSIVE_MODE] boolValue])
    {
        //dbg/log msg
        //os_log(logHandle, "client in passive mode, so allowing %{public}@ (from %{public}@)", file.destinationPath, file.process.path);
    
        //done!
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
    os_log_debug(logHandle, "found plugin %{public}@ for %{public}@", matchingPlugin, file);
    
    //allow the plugin to closely examine the event
    // it will know more about the details so can determine if it should be ignored
    if(YES == [matchingPlugin shouldIgnore:file message:message])
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
    os_log_debug(logHandle, "created event: %{public}@", event);
    
    //matches last event?
    // if so, ignore the event
    if(YES == [event isRelated:self.lastEvent includeTime:YES])
    {
        //dbg msg
        os_log_debug(logHandle, "matches last event, so ignoring");

        //update
        self.lastEvent = event;

        //skip
        goto bail;
    }

    //ignore (closely) matched alerts
    // ...that were already shown to user
    if(YES == [events wasShown:event])
    {
        //dbg msg
        os_log_debug(logHandle, "event %{public}@ matches/is related to a shown alert, so ignoring", event);

        //skip
        goto bail;
    }

    //any matching rules?
    // do this here, since we need an event and plugin obj
    matchingRule = [rules find:event];
    if(nil != matchingRule)
    {
        //dbg msg
        os_log_debug(logHandle, "found matching rule %{public}@ for %{public}@", matchingRule, file);
        
        //rule: allow
        if(ALLOW_EVENT == matchingRule.action)
        {
            //dbg msg
            os_log_debug(logHandle, "matching rule says, 'allow' ...so allowing!");
        }
        //rule: block
        else
        {
            //dbg/log msg
            os_log(logHandle, "matching rule says, 'block', so blocking %{public}@", event);
            
            //block
            if(YES != [matchingPlugin block:event])
            {
                //err msg
                os_log_error(logHandle, "ERROR: failed to block event!");
            }
        }
    
        //done!
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "no matching rule found...");
    
    //update last event
    self.lastEvent = event;
    
    //dbg msg
    os_log_debug(logHandle, "event appears to be new!, will deliver");
    
    //deliver alert
    // can fail if no client
    if(YES == [events deliver:event])
    {
        //dbg msg
        os_log_debug(logHandle, "alert delivered...");
        
        //set flag
        wasDelivered = YES;
    }
    
bail:
    
    @synchronized (event) {
        
        //not delivered?
        // free es message
        if( (YES != wasDelivered) &&
            (NULL != event.esMessage) )
        {
            //release message
            if(@available(macOS 11.0, *))
            {
                //release
                es_release_message(event.esMessage);
            }
            //free message
            else
            {
                //free
                es_free_message(event.esMessage);
            }
            
            //unset
            event.esMessage = NULL;
        }
    } //sync
    
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
        os_log_error(logHandle, "ERROR: failed to load watch list");
        
        //bail
        goto bail;
    }
    
    //load watch list
    watchList = [[NSMutableArray alloc] initWithContentsOfFile:watchListPath];
    if(nil == watchList)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to load watch list from %{public}@", watchListPath);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "watchlist: %{public}@", watchList);
    
    //iterate over all watch items
    // instantiate a plugin for each
    for(NSDictionary* watchItem in watchList)
    {
        //dbg msg
        os_log_debug(logHandle, "watch item: %{public}@/%{public}@", watchItem, NSClassFromString(watchItem[@"class"]));
        
        //grab min/max supported OS
        pluginMinOS = watchItem[@"minOSVersion"];
        pluginMaxOS = watchItem[@"maxOSVersion"];
        
        //check:
        // is system's OS version new enough to support plugin?
        if( (nil != pluginMinOS) &&
            (pluginMinOS.unsignedIntValue > NSProcessInfo.processInfo.operatingSystemVersion.majorVersion) )
        {
            //dbg msg
            os_log_debug(logHandle, "macOS %ld too old for plugin %{public}@ (min: %{public}@)", (long)NSProcessInfo.processInfo.operatingSystemVersion.majorVersion, watchItem[@"class"], pluginMinOS);
            
            //skip this plugin
            continue;
        }
        
        //check
        // is system's OS version too new to support plugin?
        if( (nil != pluginMaxOS) &&
            (pluginMaxOS.unsignedIntValue < NSProcessInfo.processInfo.operatingSystemVersion.majorVersion) )
        {
            //dbg msg
            os_log_debug(logHandle, "macOS %ld too new for plugin %{public}@ (max: %{public}@)", (long)NSProcessInfo.processInfo.operatingSystemVersion.majorVersion, watchItem[@"class"], pluginMaxOS);
            
            //skip this plugin
            continue;
        }
        
        //init plugin
        // will also init paths
        plugin = [(PluginBase*)([NSClassFromString(watchItem[@"class"]) alloc]) initWithParams:watchItem];
        if(nil == plugin)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to initialize plugin: %{public}@", watchItem[@"class"]);
            
            //skip
            continue;
        }
        
        //save plugin
        [self.plugins addObject:plugin];
    }
    
    //dbg msg
    os_log_debug(logHandle, "registered plugins: %{public}@", self.plugins);

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
    NSUInteger idx = [plugins indexOfObjectWithOptions:NSEnumerationConcurrent passingTest:^BOOL(PluginBase * _Nonnull currentPlugin, NSUInteger idx, BOOL * _Nonnull stop) {
        //is match?
        return [currentPlugin isMatch:file];
    }];
    if (idx != NSNotFound) {
        plugin = plugins[idx];
    }
    return plugin;
}

@end
