//
//  file: utilities.h
//  project: BlockBlock (shared)
//  description: various helper/utility functions (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef Utilities_h
#define Utilities_h

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <EndpointSecurity/EndpointSecurity.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#ifdef DAEMON_BUILD

enum qtn_error_code {
    QTN_NOT_QUARANTINED = -1,
};

enum qtn_flags {
    QTN_FLAG_DOWNLOAD = 0x0001,
    QTN_FLAG_SANDBOX = 0x0002,
    QTN_FLAG_USER_APPROVED = 0x0040,
};

typedef struct _qtn_file *qtn_file_t;

qtn_file_t qtn_file_alloc(void);
void qtn_file_free(qtn_file_t qf);
uint32_t qtn_file_get_flags(qtn_file_t qf);
int qtn_file_init_with_path(qtn_file_t qf, const char *path);

//get quarantine flags
uint32_t getQuarantineFlags(NSString* path);

//mach time to nano-seconds
uint64_t machTimeToNanoseconds(uint64_t machTime);

//is item downloaded
BOOL isDownloaded(NSString* path);

#endif

/* FUNCTIONS */

//give path to app
// get full path to its binary
NSString* getBundleExecutable(NSString* appPath);

//given an app binary
// try get app's bundle
NSBundle* getAppBundle(NSString* binaryPath);

//get path to (main) app
// login item is in app bundle, so parse up to get main app
NSString* getMainAppPath(void);

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion(void);

//wait for file to be written to disk
void waitForFile(NSString* path, float maxWait);

//get (true) parent
NSDictionary* getRealParent(pid_t pid);

//given a bundle path
// wait for plist, then load bundle
NSBundle* getBundle(NSString* path, float maxWait);

//extract value from plist
// takes optional wait time...
id getValueFromPlist(NSString* plistFile, NSString* key, BOOL insensitive, float maxWait);

//find 'top-level' app of binary
// useful to determine if binary (or other app) is embedded in a 'parent' app bundle
NSString* topLevelApp(NSString* binaryPath);

//verify that an app bundle is
// a) signed
// b) signed with signing auth
OSStatus verifyApp(NSString* path, NSString* signingAuth);

//get name of logged in user
NSString* getConsoleUser(void);

//start app with options
BOOL startApplication(NSURL* appPath, NSUInteger launchOptions);

//check if process is alive
BOOL isProcessAlive(pid_t processID);

//set dir's|file's group/owner
BOOL setFileOwner(NSString* path, NSNumber* groupID, NSNumber* ownerID, BOOL recursive);

//set permissions for file
BOOL setFilePermissions(NSString* file, int permissions, BOOL recursive);

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath);

//get process's path
NSString* getProcessPath(pid_t pid);

//get process name
// either via app bundle, or path
NSString* getProcessName(NSString* path);

//given a process path and user
// return array of all matching pids
NSMutableArray* getProcessIDs(NSString* processPath, int userID);

//given a pid, get its parent (ppid)
pid_t getParentID(int pid);

//figure out binary's name
// either via app bundle, or from path
NSString* getBinaryName(NSString* path);

//enable/disable a menu
void toggleMenu(NSMenu* menu, BOOL shouldEnable);

//toggle login item
// either add (install) or remove (uninstall)
BOOL toggleLoginItem(NSURL* loginItem, int toggleFlag);

//get an icon for a process
// for apps, this will be app's icon, otherwise just a standard system one
NSImage* getIconForProcess(NSString* path);

//wait until a window is non nil
// then make it modal
void makeModal(NSWindowController* windowController);

//find a process by name
pid_t findProcess(NSString* processName);

//hash a file (sha256)
NSMutableString* hashFile(NSString* filePath);

//exec a process with args
// if 'shouldWait' is set, wait and return stdout/in and termination status
NSMutableDictionary* execTask(NSString* binaryPath, NSArray* arguments, BOOL shouldWait, BOOL grabOutput);

//loads a framework
// note: assumes is in 'Framework' dir
NSBundle* loadFramework(NSString* name);

//in dark mode?
BOOL isDarkMode(void);

//check if a file is restricted (SIP)
BOOL isFileRestricted(NSString* file);

//check if something is nil
// if so, return a default ('unknown') value
NSString* valueForStringItem(NSString* item);

//convert es_string_token_t to string
NSString* convertStringToken(es_string_token_t* stringToken);

//convert a textview to a clickable hyperlink
void makeTextViewHyperlink(NSTextField* textField, NSURL* url);

//extract script via args
NSArray* getScripts(pid_t pid, NSMutableArray* args, NSString* cwd);

#ifndef DAEMON_BUILD

//build an array of processes ancestry
// note: only call from UI session, due to use of carbon APIs
NSMutableArray* generateProcessHierarchy(pid_t pid, NSString* name);

#endif

#endif
