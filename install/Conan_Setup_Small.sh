#!/bin/bash

helptext='''
Author: Dennis Hessling
E-Mail: Dennis.Hessling@gigatronik.com
This file is for a first setup of conan on a Linux machine.
If needed it installs conan, installs the PHP-relevant profiles and takes care of further setup.
'''

###
#Variables
###
PROFILES_GIT_URL=http://192.168.131.181:7990/scm/etp/profiles.git
PROFILES_GIT_URL_ALTERNATIVE=http://192.168.131.181:7990/scm/etp/profiles.git
CONAN_REMOTE_NAME=conan-etp
CONAN_REMOTE_URL=http://192.168.131.181:8081/artifactory/api/conan/conan-etp 
##
#end Variables
###

###
#helper functions
###
promptYn () {
    while true; do
        read -p "$1 " yn
        case $yn in
            [Yy]* ) return 0;;
            "" )    return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}
#Define colors for warnings
RED='\033[1;31m'
GREEN='\033[0;32m'
NC='\033[0m'
###
#end helper functions
###

#This doublecheck is helping to check paths
if [ $( which conan ) ]
then
    echo -e "${GREEN}conan installed in version $(conan --version)${NC}\n"
else
    echo -e "${RED}ERROR! Could not install conan${NC}\n"
fi

if [ ! -e ~/.conan/profiles ] || [ ! -e ~/.conan/settings.yml ]
then
    echo "Conan is not set up yet, setting up conan, just to change the settings"
    # This is really ugly and conan should have a better option!
    MYTMPDIR=$(mktemp -d)
    MYCURRENTDIR=$(pwd)
    cd $MYTMPDIR
    echo "Starting setup"
    conan new aa/bb@cc/dd > /dev/null 2>&1
    conan create . aa/bb@cc/dd > /dev/null 2>&1
    echo "Setup done"
    if [ ! -e ~/.conan/profiles ] || [ ! -e ~/.conan/settings.yml ]
    then
        echo -e "${RED}ERROR${NC} settings or profiles folder not created by conan"
    else
        echo "Created settings"
    fi
    cd $MYCURRENTDIR
    trap "rm -rf $MYTMPDIR" EXIT
fi


echo "Cloning profiles"
MYCURRENTDIR=$(pwd)
echo "Checking if profiles is empty"
mkdir -p ~/.conan/profiles
cd ~/.conan/profiles
shopt -s nullglob
files=( * .* )
# contents of files array is (. ..) if the directory is empty
if (( ${#files[@]} != 2 ))
then
    echo "Profiles currently is not empty"
    cd ..
    mv profiles profiles_backup$(date +%Y-%m-%d-%H-%M)
    mkdir profiles
    cd profiles
fi
git clone $PROFILES_GIT_URL .
if [ $? -ne 0 ]
then
    echo "Warning, could not clone profiles, trying http instead"
    echo "running git clone $PROFILES_GIT_URL_ALTERNATIVE ."
    git clone $PROFILES_GIT_URL_ALTERNATIVE .
    if [ $? -ne 0 ]
    then
        echo -e """${RED}ERROR!${NC}
        Could not clone git repository from
        $PROFILES_GIT_URL
        or
        $PROFILES_GIT_URL_ALTERNATIVE
        If needed create a ssh key with \`ssh-keygen\`
        Please add the resulting key to the remote."""
    fi
fi
cd $MYCURRENTDIR
echo "Conan profiles installed:"
conan profile list
#Allowing build release with debugging info
sed -i 's/^build_type.*/build_type: [None, Debug, Release, RelWithDebInfo, MinSizeRel]/' ~/.conan/settings.yml

#ToDo Take care of conan remotes
if [ ! -z "$(conan remote list)" ]
then
    echo "Currently available remotes should be removed, current list:"
    conan remote list
    if promptYn "Should I remove the currently registered remotes? [Yn]"
    then
        for remote in "$(conan remote list)" 
        do
            for remotename in $(echo "$remote" | sed 's/:.*//')
            do
                conan remote remove $remotename
            done
        done
    fi
fi
conan remote add $CONAN_REMOTE_NAME $CONAN_REMOTE_URL
echo "conan binary remote $CONAN_REMOTE_NAME added, if needed set user and password by running \`conan user -p <PASSWORD> -r conan-local <USERNAME>\`"

echo -e """
${GREEN}DONE!${NC}
You are all done and ready to go!
To work with conan you can now follow the next steps:

Build from source
=================

clone the folder
build it with
\`conan create . php/testing -pr <PROFILE>\`
where <PROFILE> is one of the profiles you see when typing
\`conan profile list\`

Copy from remote
================
copy from the artifactory by typing
\`conan download OpenCV/1.0.6@user/stable\`
where OpenCV/1.0.6@php/testing is an example for a package.
"""
