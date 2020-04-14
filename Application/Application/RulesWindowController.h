//
//  file: RulesWindowController.h
//  project: BlockBlock (main app)
//  description: window controller for 'rules' table (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;

#import "Rule.h"
#import "XPCDaemonClient.h"

/* CONSTS */

//id (tag) for detailed text in category table
#define TABLE_ROW_NAME_TAG 100

//id (tag) for detailed text (file)
#define TABLE_ROW_SUB_TEXT_FILE 101

//id (tag) for detailed text (item)
#define TABLE_ROW_SUB_TEXT_ITEM 102

//id (tag) for delete button
#define TABLE_ROW_DELETE_TAG 110

//menu item for block
#define MENU_ITEM_BLOCK 0

//menu item for allow
#define MENU_ITEM_ALLOW 1

//menu item for delete
#define MENU_ITEM_DELETE 2

/* INTERFACE */

@interface RulesWindowController : NSWindowController <NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate>
{
    
}

/* PROPERTIES */

//observer for rules changed
@property(nonatomic, retain)id rulesObserver;

//flag
@property BOOL shouldFilter;

//loading rules overlay
@property (weak) IBOutlet NSVisualEffectView *loadingRules;

//loading rules spinner
@property (weak) IBOutlet NSProgressIndicator *loadingRulesSpinner;

//table items
// all of the rules
@property(nonatomic, retain)NSMutableArray* rules;

//TODO: add search bar to use this!
//table items
// filtered rules
@property(nonatomic, retain)NSMutableArray* rulesFiltered;

//search box
@property (weak) IBOutlet NSSearchField *searchBox;

//top level view
@property (weak) IBOutlet NSView *view;

//window toolbar
@property (weak) IBOutlet NSToolbar *toolbar;

//table view
@property (weak) IBOutlet NSTableView *tableView;

//panel for 'add rule'
@property (weak) IBOutlet NSView *addRulePanel;

//label for add rules button
@property (weak) IBOutlet NSTextField *addRuleLabel;

//button to add rules
@property (weak) IBOutlet NSButton *addRuleButton;

//(last) added rule
@property(nonatomic,retain)NSString* addedRule;

//status message for import/export rules
@property (weak) IBOutlet NSTextField *rulesStatusMsg;

/* METHODS */

//configure (UI)
-(void)configure;

//refresh
// just reload rules
-(IBAction)refresh:(id)sender;

//TODO: add
//add a rule
//-(IBAction)addRule:(id)sender;

//delete a rule
-(IBAction)deleteRule:(id)sender;

//given a table row
// find/return the corresponding rule
-(Rule*)ruleForRow:(NSInteger)row;

@end
