#!/usr/bin/bash 

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#
#    Sync files and directories from a selected media source to all or a select single media destination.           
#                                                                                                     
#    Creation : 30 April 2023                                                                          
#    Modify Date : 29 Febrary 2024   
#    Production version : 3.0.0                                                                
#                                                                                                                           
#    After host drive selection the script looks at the other attached peripherals to see if any drives     
#    are large enough to contain the entire backup in a one-to-one backup only.                 
#                                                                                                     
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# 
# MIT License
#
# Copyright (c) 2024 Grawmpy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#---- for debug -----
#set -x 
#--------------------

# uses yad instead of zenity if found
if which yad &>/dev/null; 
then yadzen=yad ;
else yadzen=zenity ;
fi

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<       START INITIAL GLOBAL VARIABLES       >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#   Get the logged in user's username
if [[ $( whoami ) = "root" ]] ; then PRIME_SUDOER=$SUDO_USER ; else PRIME_SUDOER=$( whoami ); fi
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#   SET THE PATH TO THE MEDIA FOLDER
MEDIA_PATH="/media/${PRIME_SUDOER}"
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#    Increase the terminal window size.
printf '\033[8;38;105t'

#   List of files and directories to exclude from rsync. 
#   If you want a specific file or directory instead of a general blacklist use full path
#   FILE AND DIRECTORY BLACKLIST FOR RSYNC
unset EXCLUDES ; declare -a EXCLUDES ;
#   Linux specific directories to avoid
#   Example: EXCLUDES=('/complete/path/to/filename.file'); EXCLUDES+=('<dir_name>'); EXCLUDES+=('<file_name>') 
EXCLUDES+=('.Trash-1000') ;
EXCLUDES+=('lost+found') ;
EXCLUDES+=('timeshift') ;

#   For dual boot, avoid any Windows specific directories added to peripherals.
EXCLUDES+=('System Volume Information') ;
EXCLUDES+=('$RECYCLE.BIN') ;

#   Specific files to avoid
### NONE LISTED

#   Put the excludes into the right format to be accepted by rsync = "{ "directory1" , "directory2" , "directory3" , "file1" , "file2" }"
ALL_EXCLUDES=$( printf '%s' "{ " ; 
for each in "${!EXCLUDES[@]}"; do 
    if [[ ${EXCLUDES[each]} != "${EXCLUDES[-1]}" ]] ; 
        then printf '%s' "\"${EXCLUDES[each]}\" , " ; 
        else printf '%s' "\"${EXCLUDES[each]}\"" ; 
    fi ; 
done ; 
printf '%s\n' " }" ; ) ;

RSYNC_FLAGS=( \
--partial \
--human-readable \
--prune-empty-dirs \
--links \
--archive \
--no-i-r \
--mkpath \
--update \
--info=name0 \
--exclude="{${ALL_EXCLUDES[*]}}" \
--log-file="${RSYNC_LOG}" \
--no-motd \
)

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
##<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<        END INITIAL GLOBAL VARIABLES        >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#--------------------------------------------------------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------------------------------------------------------

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<       START OF FUNCTION DEFINITIONS      >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<              START FUNCTION              >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#
#   Insert a tab at the beginning of every line piped through this command. Easier to force a program that aligns left all the time.
TAB_OVER (){ "$@" |& sed "s/^/\t/" ; for status in "${!PIPESTATUS[@]}"; do return "${PIPESTATUS[status]}" ; done }

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>               END FUNCTION               <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

#--------------------------------------------------------------------------------------------------------------------------------------------------

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<              START FUNCTION              >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#
#   Create a pause function that works similar to the windows version

pause(){ read -nr 1 -s -r -p 'Press any key to continue...'; echo ; }

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>               END FUNCTION               <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

#--------------------------------------------------------------------------------------------------------------------------------------------------

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<              START FUNCTION              >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#
#   This function verifies whether a function has been loaded into memory and is available for use in this script. 
#   0 - found and ready, 1 - Not available (error)

VERIFY_FUNCTION(){ [[ "$(LC_ALL=C type -t "$1")" && "$(LC_ALL=C type -t "$1")" == function ]] ;}

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>               END FUNCTION               <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

#--------------------------------------------------------------------------------------------------------------------------------------------------

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<              START FUNCTION              >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#
#   The variable DRIVE_MOUNT_PATH below will be blank if anything outside of the media path is selected, or if the request is cancelled.
#   Both will give an error of a blank variable. 
#   While the variable is not set, repeat the request until it's filled, if not, exit.

function GET_HOST { 
unset DRIVE_MOUNT_PATH EXIT_CODE HOST_NAME DRIVE_NAME ;
export DRIVE_NAME ;
while  [[ -z ${HOST_NAME+x} ]] ; do
    while [[ -z ${DRIVE_MOUNT_PATH+x} ]]; do
        if ! DRIVE_MOUNT_PATH=$(${yadzen} --file-selection --title="Select a media drive" --directory --filename="${MEDIA_PATH}/${PRIME_SUDOER}") ; then 
        return 1 ; fi
    done
    HOST_NAME=$(basename "${DRIVE_MOUNT_PATH}") ;
#    if ! cd "${MEDIA_PATH}/${HOST_NAME}" ; then  echo "Attempting to change the directory failed. Exiting script."; pause ; return "$?" ; fi
    done
    DRIVE_NAME="${MEDIA_PATH}/${HOST_NAME}"
    echo "${HOST_NAME}" ; echo "${DRIVE_NAME}" ; 
    return 0 ;
}

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>               END FUNCTION               <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

#--------------------------------------------------------------------------------------------------------------------------------------------------

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<              START FUNCTION              >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#
#   Define the errorcodes produced by rsync

function TRANSLATE_ERRORCODE(){
X_CODE=$1;
    case ${X_CODE} in
        0 )    CODE="Success";;
        1 )    CODE="Syntax or usage error";;
        2 )    CODE="Protocol incompatibility";;
        3 )    CODE="Errors selecting input/output files, dirs";;
        4 )    CODE="Requested action not supported:\nAn attempt was made to manipulate 64-bit files on a platform that cannot support them;\nor an option was specified that is supported by the client and not by the server.";;
        5 )    CODE="Error starting client-server protocol";;
        6 )    CODE="Daemon unable to append to log-file";;
        10 )   CODE="Error in socket I/O";;
        11 )   CODE="Error in file I/O";;
        12 )   CODE="Error in rsync protocol data stream";;
        13 )   CODE="Received SIGUSR1 or SIGINT";;
        21 )   CODE="Some error returned by waitpid()";;
        22 )   CODE="Error allocating core memory buffers";;
        23 )   CODE="Partial transfer due to error";;
        24 )   CODE="Partial transfer due to vanished source files";;
        25 )   CODE="The --max-delete limit stopped deletions";;
        30 )   CODE="Timeout in data send/receive";;
        35 )   CODE="Timeout waiting for daemon connection";;
        *)     CODE="Invalid errorcode. Fatal error" ; X_CODE=99 ;;
    esac
    printf '"Error Code %s: \t%s\n' "${X_CODE}" "${CODE}" ; return "${X_CODE}" ;
}

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>               END FUNCTION               <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

#--------------------------------------------------------------------------------------------------------------------------------------------------

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<              START FUNCTION              >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#
#   Get the number of characters needed to create the underline section in the menu
#   The character doesn't matter here, the variable is merely for width  

UNDERLINE()(
    unset input output ;
    local input output ;
    input="$(( $1 + 3 ))" ; 
    output=$( for i in $( seq 0 ${input} ); do printf '%s' "_" ;  done )
    echo "${output}"
)

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>               END FUNCTION               <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

#--------------------------------------------------------------------------------------------------------------------------------------------------

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<              START FUNCTION              >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#
#   This function allows the user to find a windows partition by using fdisk's file information listing the type flags
#   Instead of looking for the drive type flag 'Microsoft basic data', which is the label where a Windows
#   OS C:\ drive would be located, (any ntfs formatted drive also returns a hit searching for the flag, 'Microsoft basic data')
#   we need to narrow the search down a bit more first. 
#
#   By searching instead for the 'Microsoft reserved' type flag, this will point to the same drive where the Windows 
#   OS will be installed since Microsoft places these two on the same drive during setup. By getting the first three 
#   characters of the filesystem path, after eliminating the "/dev/", we can use that informationn to narrow down the 
#   search to determine if a Windows OS drive is attached. I have successful testing on my own laptop with a dual boot 
#   Windows partition, on an nvme M.2 internal drive. If this does find the Windows OS drive partition, this next looks 
#   to see if it might be mounted and, if it is, unmount.
#   We still write this information to a variable to use to eliminate that partition from any of the rsync paths.

FIND_WIN_PARTITION()(
    unset findWindowsDrive findWinRecovPartition findWindowsCompare ;
    local findWindowsDrive findWinRecovPartition findWindowsCompare ;
    findWinRecovPartition=$(sudo fdisk -l | grep "Microsoft reserved" | awk '{print $1}') ;
    #   Moves right past first five charcters from the output ("/dev/") echoing only the next 3 characters (sd?, nvm, dis...) 
    findWindowsCompare="${findWinRecovPartition:5:3}" ;
    if eval sudo fdisk -l | grep "${findWindowsCompare}" | grep "Microsoft basic data" | awk '{print $1}' ; then 
    #   Using the infomation from above leads us to the ntfs partition of the drive containing the Windows OS.
    findWindowsDrive="$(sudo fdisk -l | grep "${findWindowsCompare}" | grep "Microsoft basic data" | grep -v "/media" | awk '{print $1}')" &>/dev/null ;
    #   Windows found ... boo ... bad ... but I have to send a successful find.
    if df | grep "$findWindowsDrive" &>/dev/null ; then sudo umount -f "$findWindowsDrive" ; fi
    #   If the drive information has been found and retrieved return success and echo the filesystem pathname as well return 0, success.
    if [[ -n "${findWindowsDrive}"  ]]; then return 0 ; fi ;
else
#   No windows partition information was found so return a failure, code = 1
    [[ -z ${findWinRecovPartition} ]] && return 1 ;
fi
)

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>               END FUNCTION               <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

#--------------------------------------------------------------------------------------------------------------------------------------------------

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<              START FUNCTION              >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#
START_CURS_DANCE(){
#   Get cursor column and row coordinates
IFS='[;' read -rsd R -p $'\e[6n' _ ROW COLUMN
sudo tput civis
echo -e "\tStarting rsync's synchronization process. "; 
echo -e "\tSyncing from ${1} to ${2}. "; 
echo -e "\tProcess may take several minutes. Please wait..." ;
tput sc
function spinner { local n i ; i=0 ; line='—\|/' ; n=${#line} ; while sleep 0.2; do tput cup "${ROW}" "${COLUMN}" ; printf "  %s\b" "${line:i++%n:1}" ; printf '\r' ; done ; }
spinner ; echo -e '\r' ; tput el & echo "$!" | tee "curs_dance_pid"  ;
}

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>               END FUNCTION               <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

#--------------------------------------------------------------------------------------------------------------------------------------------------

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<              START FUNCTION              >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#

FINIS_CURS_DANCE() { 
#    Stop the spinner animation when running spinner.sh
if ! sudo kill -9 "$(cat curs_dance_pid)" &>/dev/null ; then echo -e "kill spinner failed. Error: $?" ; fi ;
echo ;
#    Remove the file created when running spinner.sh to keep track of program ID for terminating the action
if ! sudo rm curs_dance_pid ; then echo "rm spinner failed. Error: $?" ; fi ;
echo -e '\r\nFinished...' ;
#    Put back the cursor
sudo tput cnorm ;
tput rc ;
}

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>               END FUNCTION               <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

#--------------------------------------------------------------------------------------------------------------------------------------------------

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<              START FUNCTION              >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#
#   <FOR FUTURE USE ; NOT IMPLEMENTED AT THIS TIME>
#   Separate each character in a string and output each individually. 
#   Sufficient to populate an array in use of collecting arguements passed to a command or function

separate_string()(input=$1 ; for each in $( seq 0 $(( ${#input} - 1 )) ) ; do echo "${input:$each:1}" ; done)

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>               END FUNCTION               <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<       END OF FUNCTION DEFINITIONS      >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#--------------------------------------------------------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------------------------------------------------------

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Start of gathering drive data information 
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# START SINGLE ELEMENT HOST VARIABLES 
#   Check and run the function to get select the host drive.
if VERIFY_FUNCTION GET_HOST ; then if ! DRIVE_NAME=$(GET_HOST) ; then echo "GET_HOST function failed to launch." ; pause ; exit 1 ; fi ; fi
#   Filesystem information for selected host drive
declare THIS_FILESYSTEMS ; [[ ${DRIVE_NAME} ]] && { if ! THIS_FILESYSTEMS=$(df | grep "${DRIVE_NAME}" | awk '{ print $1 }') ; 
then echo "Either the gathering of filesystem information or population of THIS_FILESYSTEMS failed." ; else readonly THIS_FILESYSTEMS ; fi } ;
#   Total storage space on the host drive
declare THIS_DRIVE_TOTAL READABLE_TOTAL ; [[ ${DRIVE_NAME} ]] && { 
if ! { 
    if THIS_DRIVE_TOTAL=$(df | grep "${DRIVE_NAME}" | awk '{ print $2 }' | sed "s/[^0-9]*//g" ) ; 
        then READABLE_TOTAL="$( echo $(( THIS_DRIVE_TOTAL * 1000  )) | numfmt --to=si --suffix="b" "$@")" ; 
    fi } ; 
then echo "Error declaring or populating the variables THIS_DRIVE_TOTAL or READABLE_TOTAL" ; else readonly READABLE_TOTAL THIS_DRIVE_TOTAL ; 
fi } ;
#   Total drive spaced used
declare THIS_DRIVE_IUSED ; [[ ${DRIVE_NAME} ]] && { 
if ! { 
    if THIS_DRIVE_IUSED=$(df | grep "${DRIVE_NAME}" | awk '{ print $3 }' | sed "s/[^0-9]*//g" ) ; 
        then READABLE_IUSED="$( echo $(( THIS_DRIVE_IUSED * 1000  )) | numfmt --to=si --suffix="b" "$@")" ; 
    fi ; } ; 
then echo "Error declaring or populating the variables THIS_DRIVE_IUSED or READABLE_IUSED" ;
else readonly THIS_DRIVE_IUSED READABLE_IUSED ; 
fi } ;
#   Total drive space used
declare THIS_DRIVE_AVAIL READABLE_IUSED ; [[ ${DRIVE_NAME} ]] && { 
if ! { 
    if THIS_DRIVE_AVAIL=$(df | grep "${DRIVE_NAME}" | awk '{ print $4 }' | sed "s/[^0-9]*//g" ) ; 
        then READABLE_AVAIL="$( echo $(( THIS_DRIVE_AVAIL * 1000  )) | numfmt --to=si --suffix="b" "$@")" ; 
    fi ; } ; 
then echo "Error declaring or populating the variables THIS_DRIVE_AVAIL or READABLE_AVAIL" ; 
else readonly THIS_DRIVE_AVAIL READABLE_AVAIL ; 
fi } ;
#   Pathway to the selected host drive
declare THIS_DRIVE_PATHS ; [[ ${DRIVE_NAME} ]] && { 
    if ! THIS_DRIVE_PATHS="$(df | grep "${DRIVE_NAME}" | awk '{ print $6 }')" ; 
        then echo "Error declaring or populating the variables THIS_DRIVE_PATHS" ; 
        else readonly THIS_DRIVE_PATHS ; 
    fi } ;
#   declare THIS_DRIVE_PCENT=
#   THIS_DRIVE_PCENT=$(df |"${WIN_PARTITION}" grep '/dev/sd' | sort -k1 | grep "${DRIVE_NAME}" | grep -v 100% | grep -v writable | awk '{ print $5 }') ;
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#   START COLLECTION OF WINDOWS DRIVES DATA
#   With this command, if there is any Windows OS partition, it should find it and give the filesystem path
if ! WIN_PARTITION=$(FIND_WIN_PARTITION) ; 
    then echo "Error declaring or populating the variable WIN_PARTITION" ; 
    else isWindowsPartition=$? ; readonly WIN_PARTITION ; 
fi

if [[ ${isWindowsPartition} ]] ; then 
    while IFS='' read -r line1; do var2+=("$line1"); done < <( df | grep -v "${WIN_PARTITION}" | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $2 }' ) ; else while IFS='' read -r line1; do var2+=("$line1"); done < <( df | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $2 }' ) ; fi

#   If there is a windows drive found, mounted or not

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#   -------------------------------------------------------------- START ARRAY VALUES -------------------------------------------------------------
#   START COLLECTION OF ARRAY DATA FOR ALL ATTACHED MEDIA DRIVES
#   Load all the filesystems into the variable ALL_FILESYSTEMS then compare to see if the destination drive is large enough to handle a one to one backup.
unset TEMP_AFS ALL_FILESYSTEMS ; declare -a TEMP_AFS ALL_FILESYSTEMS ; if [[ ${isWindowsPartition} ]] ; then 
    mapfile -t TEMP_AFS < <( df | grep -v "${WIN_PARTITION}" | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $1 }' ; ) ; else 
    mapfile -t TEMP_AFS < <( df | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $1 }' ; ) ;
fi ; for i in "${!TEMP_AFS[@]}" ; do if [[ ${THIS_DRIVE_IUSED} -lt "${var2[i]}" ]] ; then ALL_FILESYSTEMS+=("${TEMP_AFS[i]}"); fi ; done
#for i in "${!ALL_FILESYSTEMS[@]}" ; do printf '%s\n' " $i) ALL_FILESYSTEMS: ${ALL_FILESYSTEMS[i]}" ; done

#   Load all the drive totals into the variable ALL_DRIVE_TOTALS then compare to see if the destination drive is large enough to handle a one to one backup.
unset TEMP_ADT ALL_DRIVE_TOTALS HR_ALL_DRIVE_TOTALS ; declare TEMP_ADT ALL_DRIVE_TOTALS HR_ALL_DRIVE_TOTALS ; if [[ ${isWindowsPartition} ]] ; then 
    mapfile -t TEMP_ADT < <( df | grep -v "${WIN_PARTITION}" | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $2 }' | sed "s/[^0-9]*//g" ; ) ; else
    mapfile -t TEMP_ADT < <( df | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $2 }' ; ) ; 
fi ; 
    for i in "${!TEMP_ADT[@]}" ; do if [[ ${THIS_DRIVE_IUSED} -lt "${var2[i]}" ]] ; then ALL_DRIVE_TOTALS+=("${TEMP_ADT[i]}"); fi ; done
    for i in "${!ALL_DRIVE_TOTALS[@]}"; do if ! [[ "${ALL_DRIVE_TOTALS[i]}" -eq 0 ]] ; then HR_ALL_DRIVE_TOTALS+=("$( echo $(( ALL_DRIVE_TOTALS[i] * 1000  )) | numfmt --to=si --suffix="b" "$@")") ; fi ; done
    #for i in "${!ALL_DRIVE_TOTALS[@]}" ; do printf '%s\n' " $i) ALL_DRIVE_TOTALS: ${ALL_DRIVE_TOTALS[i]} --> HR_ALL_DRIVE_TOTALS: ${HR_ALL_DRIVE_TOTALS[i]}" ; done

#   Load all the drive used space into the variable ALL_DRIVE_IUSED then compare to see if the destination drive is large enough to handle a one to one backup.
unset TEMP_ADI ALL_DRIVE_IUSED HR_ALL_DRIVE_IUSED ; declare -a TEMP_ADI ALL_DRIVE_IUSED HR_ALL_DRIVE_IUSED ; if [[ ${isWindowsPartition} ]] ; then 
    mapfile -t TEMP_ADI < <( df | grep -v "${WIN_PARTITION}" | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $3 }' | sed "s/[^0-9]*//g" ; ) ; else 
    mapfile -t TEMP_ADI < <( df | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $3 }' ; ) ; fi
    for i in "${!TEMP_ADI[@]}" ; do if [[ ${THIS_DRIVE_IUSED} -lt "${var2[i]}" ]] ; then ALL_DRIVE_IUSED+=("${TEMP_ADI[i]}"); fi ; done
    for i in "${!ALL_DRIVE_IUSED[@]}"; do [[ ! "${ALL_DRIVE_IUSED[i]}" -eq 0 ]] && HR_ALL_DRIVE_IUSED+=("$( echo $(( ALL_DRIVE_IUSED[i] * 1000  )) | numfmt --to=si --suffix="b" "$@")") ; done
    #for i in "${!ALL_DRIVE_IUSED[@]}" ; do printf '%s\n' " $i) ALL_DRIVE_IUSED: ${ALL_DRIVE_IUSED[i]} --> HR_ALL_DRIVE_IUSED: ${HR_ALL_DRIVE_IUSED[i]}" ; done

#   Load all the drive used space into the variable ALL_DRIVES_AVAIL then compare to see if the destination drive is large enough to handle a one to one backup.
unset TEMP_ADA ALL_DRIVES_AVAIL HR_ALL_DRIVES_AVAIL ; declare -a TEMP_ADA ALL_DRIVES_AVAIL HR_ALL_DRIVES_AVAIL ; if [[ ${isWindowsPartition} ]] ; 
    then mapfile -t TEMP_ADA < <( df | grep -v "${WIN_PARTITION}" | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $4 }' | sed "s/[^0-9]*//g" ; ) ;
    else mapfile -t TEMP_ADA < <( df | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $4 }' ; ) ; fi ;
    for i in "${!TEMP_ADA[@]}" ; do if [[ ${THIS_DRIVE_IUSED} -lt "${var2[i]}" ]] ; then ALL_DRIVES_AVAIL+=("${TEMP_ADA[i]}"); fi ; done
    for i in "${!ALL_DRIVES_AVAIL[@]}"; do [[ ! "${ALL_DRIVES_AVAIL[i]}" -eq 0 ]] && HR_ALL_DRIVES_AVAIL+=("$( echo $(( ALL_DRIVES_AVAIL[i] * 1000  )) | numfmt --to=si --suffix="b" "$@")") ; done
    #for i in "${!ALL_DRIVES_AVAIL[@]}"; do printf '%s\n' " $i) ALL_DRIVES_AVAIL: ${ALL_DRIVES_AVAIL[i]} HR_ALL_DRIVES_AVAIL: ${HR_ALL_DRIVES_AVAIL[i]}" ; done


#   Load all the drive paths into the variable ALL_DRIVES_PATHS then compare to see if the destination drive is large enough to handle a one to one backup.
unset TEMP_ADP ALL_DRIVES_PATHS ALL_DRIVES_PATHNAMES ; declare -a TEMP_ADP ALL_DRIVES_PATHS ALL_DRIVES_PATHNAMES ; if [[ ${isWindowsPartition} ]] ; 
    then mapfile -t TEMP_ADP < <( df | grep -v "${WIN_PARTITION}" | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $6 }' ; )
    else mapfile -t TEMP_ADP < <( df | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $6 }' ; ) ; fi
    for i in "${!TEMP_ADP[@]}" ; do if [[ ${THIS_DRIVE_IUSED} -lt "${var2[i]}" ]] ; then ALL_DRIVES_PATHS+=("${TEMP_ADP[i]}"); fi ; done
    #for i in "${!ALL_DRIVES_PATHS[@]}" ; do printf '%s\n' " $i) ALL_DRIVES_PATHS: ${ALL_DRIVES_PATHS[i]}" ; done

mapfile -t ALL_DRIVES_PATHNAMES < <(  for i in "${!ALL_DRIVES_PATHS[@]}" ; do basename "${ALL_DRIVES_PATHS[i]}" | sed 's/\(.\{12\}\).*/\1.../' ; done )

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#   Kept for inclusivity
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#   Load all the drive used percentage into the variable ALL_DRIVE_PCENT then compare to see if the destination drive is large enough to handle a one to one backup.
#unset TEMP_PCT ALL_DRIVE_PCENT ; declare -a TEMP_PCT ALL_DRIVE_PCENT ; if [[ ${isWindowsPartition} ]] ; 
#    then mapfile -t TEMP_PCT < <( df | grep -v "${WIN_PARTITION}" | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $5 }' ; ) ;
#    else mapfile -t TEMP_PCT < <( df | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $5 }' ; ) ; fi
#    for i in "${!TEMP_PCT[@]}" ; do if [[ ${THIS_DRIVE_IUSED} -lt "${var2[i]}" ]] ; then ALL_DRIVE_PCENT+=("${TEMP_PCT[i]}"); fi ; done
    #for i in "${!TEMP_PCT[@]}" ; do printf '%s\n' " $i) ALL_DRIVE_PCENT: ${ALL_DRIVE_PCENT[i]}" ; done
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#   -------------------------------------------------------------- END ARRAY VALUES ---------------------------------------------------------------
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#   Count the number of files found
declare -i COUNT_FILES;            
COUNT_FILES="${#ALL_FILESYSTEMS[@]}"  ;

#   Count all the entries for each column
AFS_COUNT=${#ALL_FILESYSTEMS} ;
#ADT_COUNT=${#ALL_DRIVE_TOTALS} ;
#ADI_COUNT=${#ALL_DRIVE_IUSED} ;
#ADA_COUNT=${#ALL_DRIVES_AVAIL} ;
#PCT_COUNT=${#ALL_DRIVE_PCENT} ;
#ADP_COUNT=${#ALL_DRIVES_PATHNAMES} ;

if eval VERIFY_FUNCTION UNDERLINE ; then 
UNDER_FST=$(UNDERLINE "${AFS_COUNT}" ) ;
UNDER_ADT=$(UNDERLINE 6  ) ; # "${ADT_COUNT}" ) ; 
UNDER_ADI=$(UNDERLINE 6  ) ; # "${ADI_COUNT}" ) ; 
UNDER_ADA=$(UNDERLINE 6  ) ; # "${ADA_COUNT}" ) ; 
UNDER_ADP=$(UNDERLINE 13 ) ; # "${ADP_COUNT}" ) ; 
# UNDER_PCT=$(UNDERLINE "${PCT_COUNT}") ;
fi

#   Write the number sequence of all available drives separated by a comma for selection menu
unset NUM_SEQUENCE ; for i in $(seq 1 ${COUNT_FILES}); do if [[ $i -ne ${COUNT_FILES} ]]; then NUM_SEQUENCE+=$(printf '%s' "$i, "); else NUM_SEQUENCE+=$(printf '%s' "$i") ;fi ; done

#   Gather up all the available media drive data to place on the menu
declare -a AVAIL_DRIVES ; mapfile -t AVAIL_DRIVES < <( 
    for eachUsableDrive in "${!ALL_FILESYSTEMS[@]}"; do
        printf "%-${#UNDER_ADP}s   %-${#UNDER_FST}s   %-${#UNDER_ADT}s   %-${#UNDER_ADI}s   %-${#UNDER_ADA}s\n" \
        "${ALL_DRIVES_PATHNAMES[eachUsableDrive]}" "${ALL_FILESYSTEMS[eachUsableDrive]}" "${HR_ALL_DRIVE_TOTALS[eachUsableDrive]}" "${HR_ALL_DRIVE_IUSED[eachUsableDrive]}" "${HR_ALL_DRIVES_AVAIL[eachUsableDrive]}" ; done )

#   DEFINE THE LOG FILE FOR RSYNC TO USE TO 
! [[ -d "/home/${PRIME_SUDOER}/rsync_logs" ]] && mkdir "/home/${PRIME_SUDOER}/rsync_logs" ;
RSYNC_LOG="/home/${PRIME_SUDOER}/rsync_logs/rsync_$(date +%m-%d-%Y_%H%M).log" ;
! [[ -f "${RSYNC_LOG}" ]] && touch "${RSYNC_LOG}" ; 

#   Put everything together and run the program
while true ; do

    #   RUN THE FUNCTION TO CONFIGURE AND PRINT THE MENU TO THE SCREEN
    clear;

    #   LIST THE CURRENT DRIVE WORKING FROM
    echo -e "\t\n\n\r"
    echo -e "\\tCurrent Drive: $(basename "${DRIVE_NAME}") \e[2;37m(${THIS_FILESYSTEMS})\e[0m   Total: \e[2;37m${READABLE_TOTAL}\e[0m - Used: \e[2;37m${READABLE_IUSED}\e[0m - Avail: \e[2:37m${READABLE_AVAIL}\e[0m\r\n" ;

    #   Print the heading with titles and underline each column heading
    printf "\t   \e[2;4;22m%-${#UNDER_ADP}s\e[0m   \e[4;22m%-${#UNDER_FST}s\e[0m   \e[4;22m%-${#UNDER_ADT}s\e[0m   \e[4;22m%-${#UNDER_ADI}s\e[0m   \e[4;22m%-${#UNDER_ADA}s\e[0m\n" "Drive name" "Location" "Total " "Used " "Available " ;

    for i in $(seq 1 "${#AVAIL_DRIVES[@]}"); do     
        printf '\t\e[1;97m%s\e[0m) ' "$i" ; printf '%s\n' "${AVAIL_DRIVES[$((i-1))]}"; done

    printf '\n\a' ;
    printf '\t\e[1;97m%s\e[0m) ' "A" ; printf '%s' "Backup to ";printf '\e[1;97m\e[4;37mA\e[0m';printf '%s\r\n' "ll drives above." ;
    printf '\t\e[1;97m%s\e[0m) ' "S" ; printf '%s' "Select directory to back up to a "; printf '\e[1;97m\e[4;37mS\e[0m';printf '%s\r\n' "ingle drive" ;
    printf '\t\e[1;97m%s\e[0m) ' "D" ; printf '%s' "Select directory to back up to All "  ; printf '\e[1;97m\e[4;37mD\e[0m';printf '%s\r\n' "rives" ;
    printf '\r\n'
    printf '\t\e[1;97m%s\e[0m) ' "Q" ;printf '\e[1;97m\e[4;37mQ\e[0m';printf '%s\r\n' "uit script" ;
    printf '\n\t%s\n' "If you would like to select more than one drive, "
    printf '\t%s\n\r\n' "   enter the number of the drive above, separated by spaces."
    printf '\t%s' "Select ${NUM_SEQUENCE}, A, S, or L from the above menu: " ;

    IFS= read -r OPT &>/dev/null 2>&1 ; IFS=' ' read -r -a OPT_ARRAY <<< "$OPT"

    #   Look in the array and see if the user entered an A in the listing, this entry overrides any individual drive selection. 
    if echo "${OPT_ARRAY[@]}" | grep 'A' ; then 
        echo -en "The 'A' option was detected in the selection. Switching to syncing " ; 
        printf '\e[1;97m\e[4;37mA\e[0m';echo "ll drives." ; 
        OPT_ARRAY=("A") ;
    fi ;

    for eachDrive in "${!OPT_ARRAY[@]}"; do 
        case "${OPT_ARRAY[eachDrive]}" in
            1 )  
                zenity --notification --text="Attempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[0]}" ; 
                echo -e "\033]0;Syncing from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[0]}\007" ;
                zenity --notification --text "\t Attempting to run rsync.\r\nAttempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[0]}" ; 
                START_CURS_DANCE "${THIS_DRIVE_PATHS}" "${ALL_DRIVES_PATHS[0]}";
                if ! TAB_OVER sudo rsync "${RSYNC_FLAGS[*]}" -- "${THIS_DRIVE_PATHS}/" "${ALL_DRIVES_PATHS[0]}" 2>&1 ; then REASON="$(TRANSLATE_ERRORCODE "$?")" ; EXIT_CODE=$? ; fi
                FINIS_CURS_DANCE ;
                zenity --notification --text "rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[0]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" ; 
                
                echo "$(date +%m-%d-%Y_%H%M) --> rsync to ${ALL_DRIVES_PATHS[0]} exit status: Code: ${EXIT_CODE} - ${REASON}" | tee "${RSYNC_LOG}" &>/dev/null;;
                
                #-----------------------

            [2-"${COUNT_FILES}"] )  
                zenity --notification --text="Attempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" ; 
                echo -e "\033]0;Syncing from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}\007" ;
                zenity --notification --text "\t Attempting to run rsync.\r\nAttempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" ; 
                START_CURS_DANCE "${THIS_DRIVE_PATHS}" "${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}";
                _ sudo rsync "${RSYNC_FLAGS[*]}" -- "${THIS_DRIVE_PATHS}/" "${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" ;
                EXIT_CODE=$? ; 
                REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" ;
                FINIS_CURS_DANCE ;
                zenity --notification --text "rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" ; 
                
                echo "$(date +%m-%d-%Y_%H%M) --> rsync to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]} exit status: Code: ${EXIT_CODE} - ${REASON}" | tee "${RSYNC_LOG}" &>/dev/null;;
                
                #-----------------------

            "A"|"a" ) 
                for i in $(seq 1 "${COUNT_FILES}"); do zenity --notification --text "Attempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[$i]}" ; echo -ne "\033]0;syncing from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[$i]}\007" ;
                echo -e "\033]0;Syncing from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}\007" ;
                zenity --notification --text "\t Attempting to run rsync.\r\n Attempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" ; 
                START_CURS_DANCE "${THIS_DRIVE_PATHS}" "${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}";
                _ sudo rsync "${RSYNC_FLAGS[*]}" -- "${THIS_DRIVE_PATHS}/" "${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" ;
                EXIT_CODE=$? ; 
                REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" ;
                FINIS_CURS_DANCE ;
                zenity --notification --text "rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" ; 
                echo -e "$(date +%m-%d-%Y_%H%M) --> rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" | tee "${RSYNC_LOG}" &>/dev/null ; 
                done ;;
            
                #-----------------------
            "S"|"s" ) 
                unset SINGLE_DIR_HOST ;
                SINGLE_DIR_HOST=$(zenity --file-selection --title="Select a directory for syncing to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" --directory --filename="${MEDIA_PATH}/${PRIME_SUDOER}") &> /dev/null;
                if [[ $(( COUNT_FILES + 1 )) -gt 1 ]] ; then
                    printf "\t%s" "Select one drive, 1-${COUNT_FILES}, from the drive choices above:" ; 
                    read -r DRIVE_SEL ;
                    #   Terminal title change
                    echo -e "\033]0;Syncing from ${SINGLE_DIR_HOST} to ${DRIVE_SEL}\007" ;
                    zenity --notification --text "\t Attempting to run rsync.\r\n Attempting to run rsync from ${SINGLE_DIR_HOST} to ${DRIVE_SEL}" ; 
                    START_CURS_DANCE "${THIS_DRIVE_PATHS}" "${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}";
                    TAB_OVER sudo rsync "${RSYNC_FLAGS[*]}" -- "${THIS_DRIVE_PATHS}/" "${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" ;
                    EXIT_CODE=$? ; 
                    REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" ;
                    FINIS_CURS_DANCE ;
                    zenity --notification --text "rsync from ${SINGLE_DIR_HOST} to ${DRIVE_SEL} exit status:\nCode: ${EXIT_CODE} - ${REASON}" ;
                else 
                    until [[ "$yn" = "n" ]] || [[ "$yn" = "N" ]] || [[ "$yn" = "y" ]] || [[ "$yn" = "Y" ]]; do 
                        echo -en "\tOnly one drive detected.\n\r\tDo you wish to copy this folder to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}. Y/N? ";  
                        read -r yn ; 
                        case $yn in 
                            "Y"|"y" ) echo -e "\r\nThank you. Continuing..." ; 
                                zenity --notification --text "\t Attempting to run rsync.\r\n Attempting to run rsync from ${SINGLE_DIR_HOST} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" ; 
                                START_CURS_DANCE "${THIS_DRIVE_PATHS}" "${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}";
                                TAB_OVER sudo rsync "${RSYNC_FLAGS[*]}" -- "${THIS_DRIVE_PATHS}/" "${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" ;
                                EXIT_CODE=$? ; 
                                REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" ;
                                FINIS_CURS_DANCE ;
                                zenity --notification --text "rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" ;; 
                            "N"|"n" ) echo OK. Exiting... ; pause ; exit ;; 
                            *) echo "Selection invalid! Try again." ; pause ;
                        esac ; 
                    done
                        echo -e "$(date +%m-%d-%Y_%H%M) --> rsync to ${DRIVE_SEL}, exit status: Code: ${EXIT_CODE} - ${REASON}" | tee "${RSYNC_LOG}" &>/dev/null ;
                fi ;;
                #-----------------------

            "D"|"d" ) 
                unset SINGLE_DIR_HOST ;
                SINGLE_DIR_HOST=$(zenity --file-selection --title="Select a directory for syncing to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" --directory --filename="${MEDIA_PATH}/${PRIME_SUDOER}") &> /dev/null;
                for i in $(seq 1 "${COUNT_FILES}"); do 
                zenity --notification --text "Attempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[$i]}/" ; 
                echo -ne "\033]0;syncing from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[$i]}/\007" ;
                START_CURS_DANCE "${THIS_DRIVE_PATHS}" "${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}";
                _(){ eval "$*" |& sed "s/^/\t/" ; for status in "${!PIPESTATUS[@]}"; do return "${PIPESTATUS[status]}" ; done }
                _ sudo rsync "${RSYNC_FLAGS[*]}" -- "${THIS_DRIVE_PATHS}/" "${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" ;
                EXIT_CODE=$? ; 
                REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" ;
                FINIS_CURS_DANCE ;
                zenity --notification --text "rsync from ${SINGLE_DIR_HOST} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" ;                            
                echo -e "$(date +%m-%d-%Y_%H%M) --> rsync to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]} exit status: Code: ${EXIT_CODE} - ${REASON}" | tee "${RSYNC_LOG}" &>/dev/null ;
                done ;;

                #-----------------------

            "Q"|"q" ) 
            exit ;;

            * )
            printf '%s' "Selection invalid! Try again, " ; printf '\t%s\n' "$(read -n1 -srp 'press any key to continue...')"; ;;

        esac
    done
done
