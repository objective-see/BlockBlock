//
//  FileMonitor.h
//  FileMonitor
//
//  Created by Patrick Wardle on 9/1/19.
//  Copyright © 2020 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <EndpointSecurity/EndpointSecurity.h>

/* CONSTS */

//code signing keys
#define KEY_SIGNING_IS_NOTARIZED @"notarized"
#define KEY_SIGNATURE_STATUS @"signatureStatus"
#define KEY_SIGNATURE_SIGNER @"signatureSigner"
#define KEY_SIGNATURE_IDENTIFIER @"signatureID"
#define KEY_SIGNATURE_TEAM_IDENTIFIER @"teamID"
#define KEY_SIGNATURE_AUTHORITIES @"signatureAuthorities"

//code sign options
enum csOptions{csNone, csStatic, csDynamic};

//signers
enum Signer{None, Apple, AppStore, DevID, AdHoc};

//architectures
enum Architectures{ArchUnknown, ArchAppleSilicon, ArchIntel};

//cs options
#define CS_STATIC_CHECK YES

/* CLASSES */
@class File;
@class Process;

/* TYPEDEFS */

//block for library
typedef void (^FileCallbackBlock)(File* _Nonnull);

@interface FileMonitor : NSObject

//start monitoring
// pass in events of interest, count of said events, flag for codesigning, and callback
-(BOOL)start:(es_event_type_t* _Nonnull)events count:(uint32_t)count csOption:(NSUInteger)csOption callback:(FileCallbackBlock _Nonnull)callback;

//stop monitoring
-(BOOL)stop;

@end

/* OBJECT: FILE */

@interface File : NSObject

/* PROPERTIES */

//event
// create, write, etc...
@property u_int32_t event;

//timestamp
@property(nonatomic, retain)NSDate* _Nonnull timestamp;

//src path
@property(nonatomic, retain)NSString* _Nullable sourcePath;

//dest path
@property(nonatomic, retain)NSString* _Nullable destinationPath;

//process
@property(nonatomic, retain)Process* _Nullable process;

/* METHODS */

//init
-(id _Nullable)init:(es_message_t* _Nonnull)message csOption:(NSUInteger)csOption;

@end

/* OBJECT: PROCESS */

@interface Process : NSObject

/* PROPERTIES */

//pid
@property pid_t pid;

//ppid
@property pid_t ppid;

//rpid
@property pid_t rpid;

//user id
@property uid_t uid;

//event
// exec, fork, exit
@property u_int32_t event;

//cpu type
@property NSUInteger architecture;

//exit code
@property int exit;

//audit token
@property(nonatomic, retain)NSData* _Nullable auditToken;

//name
@property(nonatomic, retain)NSString* _Nullable name;

//path
@property(nonatomic, retain)NSString* _Nullable path;

//args
@property(nonatomic, retain)NSMutableArray* _Nonnull arguments;

//ancestors
@property(nonatomic, retain)NSMutableArray* _Nonnull ancestors;

//platform binary
@property(nonatomic, retain)NSNumber* _Nonnull isPlatformBinary;

//csflags
@property(nonatomic, retain)NSNumber* _Nonnull csFlags;

//cd hash
@property(nonatomic, retain)NSData* _Nonnull cdHash;

//signing ID
@property(nonatomic, retain)NSString* _Nonnull signingID;

//team ID
@property(nonatomic, retain)NSString* _Nonnull teamID;

//signing info
// manually generated via CS APIs if `codesign:TRUE` is set
@property(nonatomic, retain)NSMutableDictionary* _Nonnull signingInfo;

//timestamp
@property(nonatomic, retain)NSDate* _Nonnull timestamp;

/* METHODS */

//init
// flag controls code signing options
-(id _Nullable)init:(es_message_t* _Nonnull)message csOption:(NSUInteger)csOption;

//generate code signing info
// sets 'signingInfo' iVar with resuls
-(void)generateCSInfo:(NSUInteger)csOption;

@end
