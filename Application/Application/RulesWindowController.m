//
//  file: RulesWindowController.m
//  project: BlockBlock (main app)
//  description: window controller for 'rules' table
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "RuleRow.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "XPCDaemonClient.h"
#import "RulesWindowController.h"

/* GLOBALS */

//xpc daemon
extern XPCDaemonClient* xpcDaemonClient;

@implementation RulesWindowController

@synthesize rules;
@synthesize refreshing;
@synthesize refreshingIndicator;

//configure (UI)
-(void)configure
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"method '%s' invoked", __PRETTY_FUNCTION__]);
    
    //load rules
    [self loadRules];
    
    //center window
    [self.window center];
    
    //show window
    [self showWindow:self];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //table resizing settings
    [self.tableView sizeLastColumnToFit];

    return;
}

//refresh
// just reload rules
-(IBAction)refresh:(id)sender
{
    //remove all rules
    [rules removeAllObjects];
    
    //set overlay vibility
    self.overlay.hidden = YES;
    
    //reload table
    // will clear all data
    [self.tableView reloadData];
    
    //start spinner
    [self.refreshingIndicator startAnimation:nil];
    
    //show message
    self.refreshing.hidden = NO;
    
    //load rules after a bit
    // ...allows UI to show messag!
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (250 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        
        //load rules
        [self loadRules];
        
    });
    
    
    return;
}

//get rules from daemon
// then, re-load rules table
-(void)loadRules
{
    //dbg msg
    logMsg(LOG_DEBUG, @"loading rules...");
    
    //in background get rules
    // ...then load rule table table
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        //get rules
        self.rules = [[xpcDaemonClient getRules] mutableCopy];
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"received %lu rules from daemon", (unsigned long)self.rules.count]);

        //sort
        // case insensitive, by name
        [self.rules sortUsingDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:RULE_PROCESS_NAME ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]]];
           
        //show rules in UI
        // ...gotta do this on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
               
            //stop refresh spinner
            [self.refreshingIndicator stopAnimation:nil];
            
            //hide refresh msg
            self.refreshing.hidden = YES;
          
            //reload table
            [self.tableView reloadData];
          
            //select first row
            [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
            
            //set overlay vibility
            self.overlay.hidden = !(0 == self.rules.count);
             
        });

    });
    
    return;
}

//delete a rule
// grab rule, then invoke daemon to delete
-(IBAction)deleteRule:(id)sender
{
    //index of row
    // either clicked or selected row
    NSInteger row = 0;
    
    //rule
    __block Rule* rule = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"deleting rule");
    
    //sender nil?
    // invoked manually due to context menu
    if(nil == sender)
    {
        //get selected row
        row = self.tableView.selectedRow;
    }
    //invoked via button click
    // grab selected row to get index
    else
    {
        //get selected row
        row = [self.tableView rowForView:sender];
    }

    //get rule
    rule = [self ruleForRow:row];
    if(nil != rule)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"deleting rule, %@", rule]);
    
        //delete rule
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            //delete
            self.rules = [[xpcDaemonClient deleteRule:rule] mutableCopy];
            
            //sort
            // case insensitive, by name
            [self.rules sortUsingDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:RULE_PROCESS_NAME ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]]];
            
            //reload table
            // ...gotta do this on the main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                
                //reload table
                [self.tableView reloadData];
                
                //set overlay vibility
                self.overlay.hidden = !(0 == self.rules.count);
              
                //select first row
                [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
                 
            });
            
        });
    }
    
bail:
    
    return;
}

#pragma mark -
#pragma mark table delegate methods

//number of rows
-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    //row's count
    return self.rules.count;
}

//cell for table column
-(NSView*)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    //cell
    NSTableCellView *tableCell = nil;
    
    //rule obj
    Rule* rule = nil;

    //get rule
    rule = [self ruleForRow:row];
    if(nil == rule)
    {
        //bail
        goto bail;
    }
    
    //column: 'process'
    // set process icon, name and path
    if(tableColumn == tableView.tableColumns[0])
    {
        //init table cell
        tableCell = [tableView makeViewWithIdentifier:@"processCell" owner:self];
        if(nil == tableCell)
        {
            //bail
            goto bail;
        }
        
        //set icon
        tableCell.imageView.image = getIconForProcess(rule.processPath);;
        
        //set (main) text
        // name and signing id
        if(nil != rule.processSigningID)
        {
            //set text
            tableCell.textField.stringValue = [NSString stringWithFormat:@"%@ (%@)", rule.processName, rule.processSigningID];
        }
        //otherwise
        // name (and patch)
        else
        {
            //set text
            tableCell.textField.stringValue = [NSString stringWithFormat:@"%@ (%@)", rule.processName, rule.processPath]; 
        }
        
        //set sub text (file)
        ((NSTextField*)[tableCell viewWithTag:TABLE_ROW_SUB_TEXT_FILE]).stringValue = [NSString stringWithFormat:@"file: %@", rule.itemFile];
        
        //set text color to gray
        ((NSTextField*)[tableCell viewWithTag:TABLE_ROW_SUB_TEXT_FILE]).textColor = [NSColor secondaryLabelColor];
        
        //set sub text (item)
        if(nil != rule.itemObject)
        {
            //set
            ((NSTextField*)[tableCell viewWithTag:TABLE_ROW_SUB_TEXT_ITEM]).stringValue = [NSString stringWithFormat:@"item: %@", rule.itemObject];
        }
        //unknown / null
        else
        {
            ((NSTextField*)[tableCell viewWithTag:TABLE_ROW_SUB_TEXT_ITEM]).stringValue = @"item: not specified";
        }
        
        //set text color to gray
        ((NSTextField*)[tableCell viewWithTag:TABLE_ROW_SUB_TEXT_ITEM]).textColor = [NSColor secondaryLabelColor];
    }
    
    //column: 'rule'
    // set icon and rule action
    else
    {
        //init table cell
        tableCell = [tableView makeViewWithIdentifier:@"ruleCell" owner:self];
        if(nil == tableCell)
        {
            //bail
            goto bail;
        }
        
        //block
        if(RULE_STATE_BLOCK == rule.action)
        {
            //set image
            tableCell.imageView.image = [NSImage imageNamed:@"block"];
            
            //set text
            tableCell.textField.stringValue = @"block";
        }
        
        //allow
        else
        {
            //set image
            tableCell.imageView.image = [NSImage imageNamed:@"allow"];
            
            //set text
            tableCell.textField.stringValue = @"allow";
        }
    }
    
bail:
    
    return tableCell;
}

//row for view
-(NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    //row view
    RuleRow* rowView = nil;
    
    //row ID
    static NSString* const kRowIdentifier = @"RowView";
    
    //try grab existing row view
    rowView = [tableView makeViewWithIdentifier:kRowIdentifier owner:self];
    
    //make new if needed
    if(nil == rowView)
    {
        //create new
        // ->size doesn't matter
        rowView = [[RuleRow alloc] initWithFrame:NSZeroRect];
        
        //set row ID
        rowView.identifier = kRowIdentifier;
    }
    
    return rowView;
}

//given a table row
// find/return the corresponding rule
-(Rule*)ruleForRow:(NSInteger)row
{
    //rule
    Rule* rule = nil;
    
    //sanity check
    if(-1 == row)
    {
        //bail
        goto bail;
    }
    
    //sync
    @synchronized(self.rules)
    {
    
    //get rule from filtered
    if(YES == self.shouldFilter)
    {
        //sanity check
        if(row >= self.rulesFiltered.count)
        {
            //bail
            goto bail;
        }
        
        //get rule
        rule = self.rulesFiltered[row];
    }
    
    //get rule from all
    else
    {
        //sanity check
        if(row >= self.rules.count)
        {
            //bail
            goto bail;
        }
        
        //get rule
        rule = self.rules[row];
    }
        
    }//sync
    
bail:
    
    return rule;
}

//on window close
// set activation policy
-(void)windowWillClose:(NSNotification *)notification
{
     //wait a bit, then set activation policy
     dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
     ^{
         //on main thread
         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
             
             //set activation policy
             [((AppDelegate*)[[NSApplication sharedApplication] delegate]) setActivationPolicy];
             
         });
     });
    
    return;
}

@end
