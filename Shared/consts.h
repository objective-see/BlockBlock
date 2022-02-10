//
//  file: consts.h
//  project: BlockBlock (shared)
//  description: #defines and what not
//
//  created by Patrick Wardle
//  copyright (c) 2020 Objective-See. All rights reserved.
//

#ifndef consts_h
#define consts_h

//cs consts
// from: cs_blobs.h
#define CS_VALID 0x00000001
#define CS_ADHOC 0x0000002
#define CS_RUNTIME 0x00010000

//patreon url
#define PATREON_URL @"https://www.patreon.com/join/objective_see"

//sentry crash reporting URL
#define SENTRY_DSN @"https://04a1d345121247f8b62014d801d7bed2@o130950.ingest.sentry.io/1225145"

//bundle ID
#define BUNDLE_ID "com.objective-see.blockblock"

//main app bundle id
#define MAIN_APP_ID @"com.objective-see.blockblock"

//helper (login item) ID
#define HELPER_ID @"com.objective-see.blockblock.helper"

//installer (app) ID
#define INSTALLER_ID @"com.objective-see.blockblock.installer"

//installer (helper) ID
#define CONFIG_HELPER_ID @"com.objective-see.blockblock.installerHelper"

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

//log to file flag
#define LOG_TO_FILE 0x10

//install directory
#define INSTALL_DIRECTORY @"/Library/Objective-See/BlockBlock"

//preferences file
#define PREFS_FILE @"preferences.plist"

//rules file
#define RULES_FILE @"rules.plist"

//client no status
#define STATUS_CLIENT_UNKNOWN -1

//client disabled
#define STATUS_CLIENT_DISABLED 0

//client enabled
#define STATUS_CLIENT_ENABLED 1

//daemon mach name
#define DAEMON_MACH_SERVICE @"com.objective-see.blockblock"

//rule state; not found
#define RULE_STATE_NOT_FOUND -1

//rule state; block
#define RULE_STATE_BLOCK 0

//rule state; allow
#define RULE_STATE_ALLOW 1

//product version url
#define PRODUCT_VERSIONS_URL @"https://objective-see.com/products.json"

//product url
#define PRODUCT_URL @"https://objective-see.com/products/blockblock.html"

//error(s) url
#define ERRORS_URL @"https://objective-see.com/errors.html"

//support us button tag
#define BUTTON_SUPPORT_US 100

//more info button tag
#define BUTTON_MORE_INFO 101

//install cmd
#define CMD_INSTALL @"-install"

//uninstall cmd
#define CMD_UNINSTALL @"-uninstall"

//uninstall via UI
#define CMD_UNINSTALL_VIA_UI @"-uninstallViaUI"

//flag to uninstall
#define ACTION_UNINSTALL_FLAG 0

//flag to install
#define ACTION_INSTALL_FLAG 1

//flag for partial uninstall
// leave preferences file, etc.
#define UNINSTALL_PARTIAL 0

//flag for full uninstall
#define UNINSTALL_FULL 1

//add rule, block
#define BUTTON_BLOCK 0

//add rule, allow
#define BUTTON_ALLOW 1

//prefs
// got FDA
#define PREF_GOT_FDA @"gotFullDiskAccess"

//prefs
// disabled status
#define PREF_IS_DISABLED @"disabled"

//prefs
// passive mode
#define PREF_PASSIVE_MODE @"passiveMode"

//prefs
// icon mode
#define PREF_NO_ICON_MODE @"noIconMode"

//prefs
// notarizaion mode
#define PREF_NOTARIZATION_MODE @"notarizationMode"

//prefs
// update mode
#define PREF_NO_UPDATE_MODE @"noupdateMode"

//log file
#define LOG_FILE_NAME @"BlockBlock.log"

//general error URL
#define FATAL_ERROR_URL @"https://objective-see.com/errors.html"

//key for exit code
#define EXIT_CODE @"exitCode"

//new user/client notification
#define USER_NOTIFICATION @"com.objective-see.blockblock.userNotification"

//rules changed
#define RULES_CHANGED @"com.objective-see.blockblock.rulesChanged"

//first time flag
#define INITIAL_LAUNCH @"-initialLaunch"

/* INSTALLER */

//menu: 'about'
#define MENU_ITEM_ABOUT 0

//menu: 'quit'
#define MENU_ITEM_QUIT 1

//install directory
#define INSTALL_DIRECTORY @"/Library/Objective-See/BlockBlock"

//product name
#define PRODUCT_NAME @"BlockBlock"

//app name
#define APP_NAME @"BlockBlock Helper.app"

//launch daemon
#define LAUNCH_DAEMON @"BlockBlock.app"

//launch daemon plist
#define LAUNCH_DAEMON_PLIST @"com.objective-see.blockblock.plist"

//launch daemon plist (beta)
#define LAUNCH_DAEMON_BETA_PLIST @"com.objectiveSee.blockblock.plist"

//frame shift
// for status msg to avoid activity indicator
#define FRAME_SHIFT 45

//flag to close
#define ACTION_CLOSE_FLAG -1

//cmdline flag to uninstall
#define ACTION_UNINSTALL @"-uninstall"

//flag to uninstall
#define ACTION_UNINSTALL_FLAG 0

//cmdline flag to uninstall
#define ACTION_INSTALL @"-install"

//flag to install
#define ACTION_INSTALL_FLAG 1

//button title: upgrade
#define ACTION_UPGRADE @"Upgrade"

//button title: close
#define ACTION_CLOSE @"Close"

//button title: next
#define ACTION_NEXT @"Next »"

//flag to show full disk access
#define ACTION_SHOW_FDA 3

//show friends
#define ACTION_SHOW_SUPPORT 4

//support us
#define ACTION_SUPPORT 5

//register
#define LSREGISTER @"/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

/* (HELPER) APP */

//path to osascript
#define OSASCRIPT @"/usr/bin/osascript"

//path to open
#define OPEN @"/usr/bin/open"

//log activity button
#define PREF_LOG_ACTIVITY @"logActivity"

//keys for rule dictionary
#define RULE_PROCESS_PATH @"processPath"
#define RULE_PROCESS_NAME @"processName"
#define RULE_PROCESS_SIGNINGID @"processSigningID"
#define RULE_ITEM_FILE @"itemFile"
#define RULE_ITEM_OBJECT @"itemObject"
#define RULE_ACTION @"action"

//block watch event
#define BLOCK_EVENT 0

//allow watch event
#define ALLOW_EVENT 1

//scope for action
// from dropdown in alert window
#define ACTION_SCOPE_UNSELECTED -1
#define ACTION_SCOPE_ALL 0
#define ACTION_SCOPE_FILE 1
#define ACTION_SCOPE_PROCESS 2

//keys for alert dictionary
#define ALERT_UUID @"uuid"
#define ALERT_MESSAGE @"message"
#define ALERT_TIMESTAMP @"timestamp"

#define ALERT_PROCESS_ID @"pid"
#define ALERT_PROCESS_PATH @"path"
#define ALERT_PROCESS_ARGS @"args"
#define ALERT_PROCESS_NAME @"processName"
#define ALERT_PROCESS_ANCESTORS @"processAncestors"
#define ALERT_PROCESS_SIGNING_INFO @"signingInfo"

//signing info (from ESF)
#define CS_FLAGS @"csFlags"
#define PLATFORM_BINARY @"platformBinary"
#define TEAM_ID @"teamID"
#define SIGNING_ID @"signingID"

#define ALERT_TYPE @"alertType"
#define ALERT_TYPE_FILE 1
#define ALERT_TYPE_PROCESS 2

#define ALERT_ITEM_NAME @"itemName"
#define ALERT_ITEM_FILE @"itemFile"
#define ALERT_ITEM_OBJECT @"itemObject"
#define ALERT_ITEM_FILE_RESTRICTED @"isRestricted"

#define ALERT_USER @"user"
#define ALERT_IPADDR @"ipAddr"
#define ALERT_HOSTNAME @"hostName"
#define ALERT_PORT @"port"
#define ALERT_PROTOCOL @"protocol"
#define ALERT_ACTION @"action"
#define ALERT_ACTION_SCOPE @"actionScope"
#define ALERT_TEMPORARY @"tempRule"

#define ALERT_PIDS @"pids"
#define ALERT_HASH @"hash"

//keys for rules
#define KEY_RULES @"rules"
#define KEY_CS_FLAGS @"csFlags"

//rules window
#define WINDOW_RULES 0

//preferences window
#define WINDOW_PREFERENCES 1

//key for stdout output
#define STDOUT @"stdOutput"

//key for stderr output
#define STDERR @"stdError"

//key for exit code
#define EXIT_CODE @"exitCode"

//TODO: make enum?
//plugin types
#define PLUGIN_TYPE_KEXT 1
#define PLUGIN_TYPE_LAUNCHD 2
#define PLUGIN_TYPE_LOGIN_ITEM 3
#define PLUGIN_TYPE_CRON_JOB 4
#define PLUGIN_TYPE_APP_LOGIN_ITEM 5
#define PLUGIN_TYPE_EVENT_MONITOR 6
#define PLUGIN_TYPE_PROCESS_MONITOR 7

//path to kextunload
#define KEXT_UNLOAD @"/sbin/kextunload"

//path to launchctl
#define LAUNCHCTL @"/bin/launchctl"

//path to killall
#define KILL_ALL @"/usr/bin/killall"

#endif
