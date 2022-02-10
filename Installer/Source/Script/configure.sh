#!/bin/bash

#
#  file: configure.sh
#  project: blockblock (configure)
#  description: install/uninstall
#
#  created by Patrick Wardle
#  copyright (c) 2017 Objective-See. All rights reserved.
#

#where BlockBlock goes
INSTALL_DIRECTORY="/Library/Objective-See/BlockBlock"

#preferences
PREFERENCES="$INSTALL_DIRECTORY/preferences.plist"

#OS version check
# only support 10.15+
OSVers="$(sw_vers -productVersion)"

if [[ ("${OSVers:0:2}" -eq 10) ]]; then
    if [[ "$OSVers" != 10.15.* ]]; then
        printf "\nERROR: ${OSVers} is currently unsupported\n"
        printf "      BlockBlock requires macOS 10.15+\n\n"
        exit -1
    fi
fi

#auth check
# gotta be root
if [ "${EUID}" -ne 0 ]; then
    echo "\nERROR: must be run as root\n"
    exit -1
fi

#install logic
if [ "${1}" == "-install" ]; then

    echo "installing"

    #change into dir
    cd "$(dirname "${0}")"

    #remove all xattrs
    xattr -rc ./*

    #create main BlockBlock directory
    mkdir -p $INSTALL_DIRECTORY

    #install launch daemon
    chown -R root:wheel "BlockBlock.app"
    chown -R root:wheel "com.objective-see.blockblock.plist"
    
    cp -R -f "BlockBlock.app" $INSTALL_DIRECTORY
    cp "com.objective-see.blockblock.plist" /Library/LaunchDaemons/
    echo "launch daemon installed"
    
    #install app
    cp -R -f "BlockBlock Helper.app" "/Applications"
    echo "app installed"
    
    #no preferences?
    # create defaults
    if [ ! -f "$PREFERENCES" ]; then
    
        /usr/libexec/PlistBuddy -c 'add disabled bool false' $PREFERENCES
        /usr/libexec/PlistBuddy -c 'add noIconMode bool false' $PREFERENCES
        /usr/libexec/PlistBuddy -c 'add noAlertMode bool false' $PREFERENCES
        /usr/libexec/PlistBuddy -c 'add notarizationMode bool false' $PREFERENCES
        /usr/libexec/PlistBuddy -c 'add noUpdateMode bool false' $PREFERENCES
        /usr/libexec/PlistBuddy -c 'add gotFullDiskAccess bool false' $PREFERENCES
        
    fi

    echo "install complete"
    exit 0

#uninstall logic
elif [ "${1}" == "-uninstall" ]; then

    #logged in user
    user=`defaults read /Library/Preferences/com.apple.loginwindow lastUserName`

    echo "uninstalling"
    
    #uninstall beta?
    BETA="/Library/LaunchDaemons/com.objectiveSee.blockblock.plist"
    if test -f "$BETA"; then
       
        #unload/remove launch agent
        if [ -n "$user" ]; then
            launchctl unload "/Users/$user/Library/LaunchAgents/com.objectiveSee.blockblock.plist"
            rm "/Users/$user/Library/LaunchAgents/com.objectiveSee.blockblock.plist"
        fi
        
        launchctl unload "/Library/LaunchDaemons/com.objectiveSee.blockblock.plist"
        rm "/Library/LaunchDaemons/com.objectiveSee.blockblock.plist"
        
        #avoid FDA cache issues
        pkill -HUP -u root -f tccd
    fi
    
    #unload launch daemon & remove its plist
    launchctl unload "/Library/LaunchDaemons/com.objective-see.blockblock.plist"
    rm "/Library/LaunchDaemons/com.objective-see.blockblock.plist"
    rm -rf "$INSTALL_DIRECTORY/BlockBlock.app"

    echo "unloaded launch daemon"

    #remove main app/helper app
    rm -rf "/Applications/BlockBlock Helper.app"

    #full uninstall?
    # delete BlockBlock's folder w/ everything
    if [[ "${2}" -eq "1" ]]; then
        rm -rf $INSTALL_DIRECTORY

        #no other Objective-See tools?
        # then delete that directory too
        baseDir=$(dirname $INSTALL_DIRECTORY)

        if [ ! "$(ls -A $baseDir)" ]; then
            rm -rf $baseDir
        fi
    fi

    #kill
    killall BlockBlock 2> /dev/null
    killall com.objective-see.BlockBlock.helper 2> /dev/null
    killall "BlockBlock Helper" 2> /dev/null

    echo "uninstall complete"
    exit 0
fi

#invalid args
echo ""
echo "ERROR: run w/ '-install' or '-uninstall'"
echo ""
exit -1
