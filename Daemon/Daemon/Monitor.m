//
//  Watcher.m
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
    
    //dbg msg
    logMsg(LOG_DEBUG, @"starting file monitor");
    
    //events of interest
    // also pass in process exec/exit to capture args
    es_event_type_t events[] = {ES_EVENT_TYPE_NOTIFY_CREATE, ES_EVENT_TYPE_NOTIFY_WRITE, ES_EVENT_TYPE_NOTIFY_RENAME, ES_EVENT_TYPE_NOTIFY_EXEC, ES_EVENT_TYPE_NOTIFY_EXIT};
    
    //init monitor
    fileMon = [[FileMonitor alloc] init];
    
    //define block
    // automatically invoked upon file events
    FileCallbackBlock block = ^(File* file)
    {
        //dbg msg
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"file event: %@", file]);
        
        @autoreleasepool
        {
            //process file event
            // match alert, etc...
            [self processEvent:file];
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
        
    //start monitoring
    // pass in block for events
    started = [self.fileMon start:events count:sizeof(events)/sizeof(events[0]) csOption:csNone callback:block];
    
    //start process monitor
    if(YES != [self startProcessMonitor])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to start process monitor");
        
        //bail
        goto bail;
    }
    
bail:

    return started;
}

//start process monitor
// for now, only ES_EVENT_TYPE_AUTH_EXEC events
-(BOOL)startProcessMonitor
{
    //flag
    BOOL started = NO;
    
    //result
    es_new_client_result_t result = 0;
    
    //events
    es_event_type_t procEvents[] = {ES_EVENT_TYPE_AUTH_EXEC};
    
    //process plugin
    __block PluginBase* plugin = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"starting process monitor...");
    
    //look up processes plugin
    [plugins enumerateObjectsUsingBlock:^(PluginBase* currentPlugin, NSUInteger index, BOOL* stop)
    {
        //is match?
        if(YES == [currentPlugin isKindOfClass:Processes.class])
        {
            //save
            plugin = currentPlugin;
            
            //stop
            *stop = YES;
        }
    }];
    
    //create client
    // and handle process (auth exec) events
    result = es_new_client(&endpointProcessClient, ^(es_client_t *client, const es_message_t *message)
    {
        //event
        Event* event = nil;
        
        //new process event
        Process* process = nil;
        
        //esf deadline
        uint64_t deadline = 0;
        
        //deadline sema
        dispatch_semaphore_t deadlineSema = 0;
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"new process event: %x", message->event_type]);
        
        //check prefs
        // allow if passive mode, or not in notarization mode
        if( (YES == [preferences.preferences[PREF_PASSIVE_MODE] boolValue]) ||
            (YES != [preferences.preferences[PREF_NOTARIZATION_MODE] boolValue]) )
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"allowing process, due to preferences (%@)", preferences.preferences]);
            
            //allow
            if(YES != [self allowProcessEvent:client message:(es_message_t*)message shouldFree:NO])
            {
                //err msg
                logMsg(LOG_ERR, @"failed to allow process");
            }
            
            //done
            return;
        }
        
        //init process obj
        process = [[Process alloc] init:(es_message_t* _Nonnull)message csOption:csDynamic];
        if( (nil == process) ||
            (YES == [plugin shouldIgnore:process]) )
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"allowing %@", process]);
            
            //allow
            if(YES != [self allowProcessEvent:client message:(es_message_t*)message shouldFree:NO])
            {
                //err msg
                logMsg(LOG_ERR, @"failed to allow process");
            }
            
            //done
            return;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"alerting user about: %@", process]);
        
        //init event
        event = [[Event alloc] init:process plugin:plugin];
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"alerting user w/: %@", event]);
        
        //add client
        event.esfClient = client;
        
        //add msg
        event.esfMessage = es_copy_message(message);
        
        //create deadline semaphore
        deadlineSema = dispatch_semaphore_create(0);
        
        //init deadline
        deadline = message->deadline - mach_absolute_time();
        
        //add to event
        event.esfSemaphore = deadlineSema;
        
        //background
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        
        //deliver alert
        // can fail if no client
        if(YES == [events deliver:event])
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"alert delivered, waiting for response...");
            
            //wait till close to timeout
            // if haven't hit, just allow, otherwise we'll be killed
            if(0 != dispatch_semaphore_wait(deadlineSema, dispatch_time(DISPATCH_TIME_NOW, machTimeToNanoseconds(deadline) - (1 * NSEC_PER_SEC))))
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"esf timeout (%llx seconds) about to be hit, forced to allow process :/", machTimeToNanoseconds(deadline) / NSEC_PER_SEC]);
                
                //sync
                @synchronized(self)
                {
                    //allow
                    if(YES != [self allowProcessEvent:client message:(es_message_t*)message shouldFree:YES])
                    {
                        //err msg
                        logMsg(LOG_ERR, @"failed to allow process");
                    }
                    
                    //unset
                    event.esfClient = NULL;
                    event.esfMessage = NULL;
                }
            }
            //sema signal'd
            // handled by user, all good
            else
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"esf semaphore signaled, alert was handled");
            }
        }
        //failed to deliver
        // will just allow process
        else
        {
            //err msg
            logMsg(LOG_ERR, @"failed to deliver message, will allow process :/");
            
            //sync
            @synchronized(self)
            {
                //allow
                if(YES != [self allowProcessEvent:client message:(es_message_t*)message shouldFree:YES])
                {
                    //err msg
                    logMsg(LOG_ERR, @"failed to allow process");
                }
                
                //unset
                event.esfClient = NULL;
                event.esfMessage = NULL;
            }
        }
            
        });
    });
    
    //sanity check
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"'es_new_client' failed with %x", result]);
        
        //bail
        goto bail;
    }
    
    //subscribe
    if(ES_RETURN_SUCCESS != es_subscribe(endpointProcessClient, procEvents, sizeof(events)/sizeof(procEvents[0])))
    {
        //err msg
        logMsg(LOG_ERR, @"'es_subscribe' failed");
        
        //bail
        goto bail;
    }

    //happy
    started = YES;
    
bail:
    
    return started;
}

//allow process event
-(BOOL)allowProcessEvent:(es_client_t*)client message:(es_message_t*)message shouldFree:(BOOL)shouldFree
{
    //flag
    BOOL allowed = NO;
    
    //result
    __block es_respond_result_t result = !ES_RESPOND_RESULT_SUCCESS;
    
    //allow
    result = es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false);
    if(ES_RESPOND_RESULT_SUCCESS != result)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"'es_respond_auth_result' failed with %x", result]);
    }
    //ok!
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"allowed process via 'es_respond_auth_result/ES_AUTH_RESULT_ALLOW'");
    }
    
    //free?
    if(YES == shouldFree)
    {
        //free msg
        es_free_message(message);
        message = NULL;
    }
    
    //happy
    allowed = YES;
    
    return allowed;
}

//start process monitor
-(BOOL)stopProcessMonitor
{
    //flag
    BOOL stopped = NO;
    
    //sync
    @synchronized (self) {
        
    //dbg msg
    logMsg(LOG_DEBUG, @"stopping process monitor...");
        
    //sanity check
    if(NULL == endpointProcessClient) goto bail;
    
    //unsubscribe
    if(ES_RETURN_SUCCESS != es_unsubscribe_all(endpointProcessClient))
    {
       //err msg
       logMsg(LOG_ERR, @"'es_unsubscribe_all' failed");
       
       //bail
       goto bail;
    }
        
    //dbg msg
    logMsg(LOG_DEBUG, @"unsubscribed from process events");
       
    //delete client
    if(ES_RETURN_SUCCESS != es_delete_client(endpointProcessClient))
    {
       //err msg
       logMsg(LOG_ERR, @"'es_delete_client' failed");
       
       //bail
       goto bail;
    }
        
    //dbg msg
    logMsg(LOG_DEBUG, @"deleted endpoint client");
       
    //unset
    endpointProcessClient = NULL;
       
    //happy
    stopped = YES;
            
    }//sync
    
bail:
    
    return stopped;
}

//stop file monitor
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
    
    //dbg msg
    logMsg(LOG_DEBUG, @"stopped file monitor");
    
    //unset
    self.fileMon = nil;
    
    //stop process monitor
    if(YES != [self stopProcessMonitor])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to stop process monitor");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"stopped process monitor");
    
    //happy
    stopped = YES;
    
bail:

    return stopped;
}

//process a file event
// a) determine if it's an event of interest
// b) then, build and deliver alert to the user
-(void)processEvent:(File*)file
{
    //event
    Event* event = nil;
    
    //matching rule (if any)
    Rule* matchingRule = nil;
    
    //plugin
    PluginBase* plugin = nil;
    
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

    //find plugin
    // ...that cares about the path/file that was just created
    plugin = [self findPlugin:file];
    if(nil == plugin)
    {
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found plugin %@ for %@", plugin, file]);
    
    //allow the plugin to closely examine the event
    // it will know more about the details so can determine if it should be ignored
    if(YES == [plugin shouldIgnore:file])
    {
        //ignore
        goto bail;
    }
    
    //create event
    event = [[Event alloc] init:file plugin:plugin];
    
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
            if(YES != [event.plugin block:event])
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
    // can fail if not client
    if(YES == [events deliver:event])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"alert delivered...");
    }
    
bail:

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
    
    //get path to watch list
    watchListPath = [[NSBundle mainBundle] pathForResource:@"watchList" ofType:@"plist"];
    if(nil == watchListPath)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to load watch list path");
        
        //bail
        goto bail;
    }
    
    //load watch list
    watchList = [[NSMutableArray alloc] initWithContentsOfFile:watchListPath];
    if(nil == watchList)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to load watch list");
        
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
