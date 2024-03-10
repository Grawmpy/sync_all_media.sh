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

#   DEFINE THE LOG FILE FOR RSYNC TO USE TO 
! [[ -d "/home/${PRIME_SUDOER}/rsync_logs" ]] && mkdir "/home/${PRIME_SUDOER}/rsync_logs" ;
RSYNC_LOG="/home/${PRIME_SUDOER}/rsync_logs/rsync_$(date +%m-%d-%Y_%H%M).log" ;
! [[ -f "${RSYNC_LOG}" ]] && touch "${RSYNC_LOG}" ; 

#   Exclude list is below
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<              START FUNCTION              >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#
#   List of files and directories to exclude from rsync. 
#   If you want a specific file or directory instead of a general blacklist use full path not including "/media/<drivename>/"
#   Enter any exclusions below in the form of "excludes+=('<file or directory name>') ; "
#   The reason I am doing this here is that I need to have the host drive chosen before I can check to see if the excluded files exist.
#   Making the checking and adding the files or directories more accurate than just assigning all exclusion variables risking file not found errors.
FIND_EXCLUDES(){ unset excludes host ALL_EXCLUDES ; 
#   Input the path of the host media drive.

declare -ax ALL_EXCLUDES ;
local excludes host;
host="${DRIVE_NAME}" ;
    #   Linux specific directories to avoid
    excludes+=( "${host}"/'.Trash-1000' ) ;
    excludes+=( "${host}"/'lost+found' ) ;
    excludes+=( "${host}"/'timeshift' ) ;
#   Add additional files or directories in the following format
    #excludes+=('<filename>') ;

    #   For dual boot Windows systems
    # shellcheck disable=SC2016
    excludes+=( "${host}"/'System Volume Information' ) ;
    # shellcheck disable=SC2016
    excludes+=( "${host}"/'$RECYCLE.BIN' ) ;

    #   Specific files to avoid
    ### NONE LISTED

    #   Put the excludes into the right format to be accepted by rsync = "-f'-directory1' -f'-directory2' -f'-directory3' -f'-file1' -f'-file2'"
    mapfile -t ALL_EXCLUDES < <( 
    if [[ "${excludes[1]}" == '' ]] ; then printf '%s' "--exclude=""${excludes[0]}""" ; 
    elif [[ "${excludes[0]}" == '' ]] ; then printf '%s' "" ; 
    fi
    printf '%s' "{ "
    for each in "${!excludes[@]}"; do 
        if [[ -f "${excludes[each]}" ]] || [[ -d "${excludes[each]}" ]] ; then
            if [[ "${excludes[each]}" != "${excludes[-1]}" ]] ; 
                then printf '%s' "\"${excludes[each]}\" , "  ;  
                else printf '%s' "\"${excludes[each]}\" " ; 
            fi ; 
        fi ;
    done ;     
    echo "}" ;
)
    echo "${ALL_EXCLUDES[@]}"
 } ;



#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>               END FUNCTION               <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

#--------------------------------------------------------------------------------------------------------------------------------------------------
    
#RSYNC_FLAGS=( --partial --human-readable --prune-empty-dirs --links --archive --mkpath --info=name0 --exclude="{${ALL_EXCLUDES[*]}}" --log-file="${RSYNC_LOG}" --no-motd )

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
#   Insert a tab at the beginning of every line piped through this command. Multiple calls enter multiple tabs.
#   Force a tab before stdout of a program like rsync that aligns all output to the left edge all the time.
TAB_OVER (){ "$@" |& sed "s/^/\t/" ; for status in "${!PIPESTATUS}"; do IFS='[;' return "${PIPESTATUS}" ; done }

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>               END FUNCTION               <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

#--------------------------------------------------------------------------------------------------------------------------------------------------

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<              START FUNCTION              >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#
#   Create a pause function that works similar to the windows version

pause()( printf '%s\n'  "$(read -rsn 1 -p 'Press any key to continue...')" ) ;

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

GET_HOST() { 
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
    DRIVE_NAME="${MEDIA_PATH}/${HOST_NAME}" ;
    if ! cd "${DRIVE_NAME}" ; then echo -ne "Changing directory to ${DRIVE_NAME} failed. Attempting another try." ; else 
        if ! cd "${DRIVE_NAME}" ; then echo -ne "Second attempt at changing directory to ${DRIVE_NAME} failed. Exiting." ; pause ; exit ; fi
    fi 
    echo -e "${DRIVE_NAME}\n" ; 
    return 0 ;
}

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>               END FUNCTION               <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

#--------------------------------------------------------------------------------------------------------------------------------------------------

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<              START FUNCTION              >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#
#   Define the errorcodes produced by rsync

TRANSLATE_ERRORCODE(){
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
START_CURS_DANCE() {
IFS='[;' read -rsd R -p $'\e[6n' _ ROW COLUMN
tput init ;
tput sc ;
tput civis ;
echo -e "\tStarting rsync's synchronization process. " ; 
echo -e  "\tThis process may take several minutes to complete. Please wait..." ;
spinner() { local n i ; i=0 ; line='—\|/' ; n=${#line} ; while sleep 0.2; do tput cup "${ROW}" "${COLUMN}" ; printf "  %s\b" "${line:i++%n:1}" ; printf '\r' ; done ; }
spinner & echo "$!" | tee "curs_dance_pid" &>/dev/null ;
}

### ---------------------------------------------------------------- END FUNCTION -----------------------------------------------------------------
###################################################################################################################################################


###################################################################################################################################################
### --------------------------------------------------------------- START FUNCTION ----------------------------------------------------------------

FINIS_CURS_DANCE() { 
    #    Stop the spinner animation when running spinner.sh
    sudo kill -9 "$(cat < curs_dance_pid)" &>/dev/null; ERROR_CODE=$?
        if [[ ${ERROR_CODE} -ne 0 ]]; then echo "kill spinner failed. Error: ${ERROR_CODE}" ; fi
    unset ERROR_CODE;
    echo -ne "\n\r"
#    Remove the file created when running spinner.sh to keep track of program ID for terminating the action
    sudo rm curs_dance_pid; ERROR_CODE=$?
        if [[ ${ERROR_CODE} -ne 0 ]]; then echo "rm spinner failed. Error: ${ERROR_CODE}" ; fi
    unset ERROR_CODE;

    echo -e '\r\nFinished...'
#    Put back the cursor
    sudo tput cnorm;
    tput rc
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
declare THIS_FILESYSTEMS ; [[ ${DRIVE_NAME} ]] && { if ! THIS_FILESYSTEMS=$(df | grep "$(basename "${DRIVE_NAME}")" | awk '{ print $1 }') ; 
then echo "Either the gathering of filesystem information or population of THIS_FILESYSTEMS failed." ; fi } ;
#   Total storage space on the host drive
declare THIS_DRIVE_TOTAL READABLE_TOTAL ; [[ ${DRIVE_NAME} ]] && { 
if ! { 
    if THIS_DRIVE_TOTAL=$(df | grep "$(basename "${DRIVE_NAME}")" | awk '{ print $2 }' | sed "s/[^0-9]*//g" ) ; 
        then READABLE_TOTAL="$( echo $(( THIS_DRIVE_TOTAL * 1000  )) | numfmt --to=si --suffix="b" "$@")" ; 
    fi } ; 
then echo "Error declaring or populating the variables THIS_DRIVE_TOTAL or READABLE_TOTAL" ; 
fi } ;
#   Total drive spaced used
declare THIS_DRIVE_IUSED ; [[ ${DRIVE_NAME} ]] && { 
if ! { 
    if THIS_DRIVE_IUSED=$(df | grep "$(basename "${DRIVE_NAME}")" | awk '{ print $3 }' | sed "s/[^0-9]*//g" ) ; 
        then READABLE_IUSED="$( echo $(( THIS_DRIVE_IUSED * 1000  )) | numfmt --to=si --suffix="b" "$@")" ; 
    fi ; } ; 
then echo "Error declaring or populating the variables THIS_DRIVE_IUSED or READABLE_IUSED" ;
fi } ;
#   Total drive space used
declare THIS_DRIVE_AVAIL READABLE_IUSED ; [[ ${DRIVE_NAME} ]] && { 
if ! { 
    if THIS_DRIVE_AVAIL=$(df | grep "$(basename "${DRIVE_NAME}")" | awk '{ print $4 }' | sed "s/[^0-9]*//g" ) ; 
        then READABLE_AVAIL="$( echo $(( THIS_DRIVE_AVAIL * 1000  )) | numfmt --to=si --suffix="b" "$@")" ; 
    fi ; } ; 
then echo "Error declaring or populating the variables THIS_DRIVE_AVAIL or READABLE_AVAIL" ; 
fi } ;
#   Pathway to the selected host drive
declare THIS_DRIVE_PATHS ; [[ ${DRIVE_NAME} ]] && { 
    if ! THIS_DRIVE_PATHS="$(df | grep "$(basename "${DRIVE_NAME}")" | awk '{ print $6 }')" ; 
        then echo "Error declaring or populating the variables THIS_DRIVE_PATHS" ; 
    fi } ;
#   declare THIS_DRIVE_PCENT=
#   THIS_DRIVE_PCENT=$(df |"${WIN_PARTITION}" grep '/dev/sd' | sort -k1 | grep "$(basename "${DRIVE_NAME}")" | grep -v 100% | grep -v writable | awk '{ print $5 }') ;
vars=( THIS_FILESYSTEMS THIS_DRIVE_TOTAL READABLE_TOTAL THIS_DRIVE_IUSED THIS_DRIVE_AVAIL READABLE_IUSED THIS_DRIVE_AVAIL READABLE_IUSED THIS_DRIVE_PATHS )
for i in "${!vars[@]}" ; do readonly "${vars[@]}" ; done
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
UNDER_ADP=$(UNDERLINE 15 ) ; # "${ADP_COUNT}" ) ; 
# UNDER_PCT=$(UNDERLINE "${PCT_COUNT}") ;
fi

#   Write the number sequence of all available drives separated by a comma for selection menu
unset NUM_SEQUENCE ; for i in $(seq 1 ${COUNT_FILES}); do if [[ $i -ne ${COUNT_FILES} ]]; then NUM_SEQUENCE+=$(printf '%s' "$i, "); else NUM_SEQUENCE+=$(printf '%s' "$i") ;fi ; done

#   Gather up all the available media drive data to place on the menu
declare -a AVAIL_DRIVES ; mapfile -t AVAIL_DRIVES < <( 
    for eachUsableDrive in "${!ALL_FILESYSTEMS[@]}"; do
        printf "%-${#UNDER_ADP}s\t%-${#UNDER_FST}s\t%-${#UNDER_ADT}s\t%-${#UNDER_ADI}s\t%-${#UNDER_ADA}s\n" \
        "${ALL_DRIVES_PATHNAMES[eachUsableDrive]}" "${ALL_FILESYSTEMS[eachUsableDrive]}" "${HR_ALL_DRIVE_TOTALS[eachUsableDrive]}" "${HR_ALL_DRIVE_IUSED[eachUsableDrive]}" "${HR_ALL_DRIVES_AVAIL[eachUsableDrive]}" ; done )

#   Put everything together and run the program
while true ; do

    #   RUN THE FUNCTION TO CONFIGURE AND PRINT THE MENU TO THE SCREEN
    clear;

    #   LIST THE CURRENT DRIVE WORKING FROM
    echo -e "\n\n\r"
    echo -e "  \tCurrent Drive: $(basename "${DRIVE_NAME}") \e[2;37m(${THIS_FILESYSTEMS})\e[0m   Total: \e[2;37m${READABLE_TOTAL}\e[0m - Used: \e[2;37m${READABLE_IUSED}\e[0m - Avail: \e[2:37m${READABLE_AVAIL}\e[0m\r\n" ;

    #   Print the heading with titles and underline each column heading
    printf "\t\e[2;4;22m%-${#UNDER_ADP}s\e[0m\t\e[4;22m%-${#UNDER_FST}s\e[0m\t\e[4;22m%-${#UNDER_ADT}s\e[0m\t\e[4;22m%-${#UNDER_ADI}s\e[0m\t\e[4;22m%-${#UNDER_ADA}s\e[0m\n" "Drive name" "Location" "Total " "Used " "Available " ;

    for i in $(seq 1 "${#AVAIL_DRIVES[@]}"); do     
        printf '\t\e[1;97m%s\e[0m) ' "$i" ; printf ' %s\n' "${AVAIL_DRIVES[$((i-1))]}"; done

    echo -en '\n\n\a' ;
    echo -en "\t\e[1;97mA\e[0m)  Backup to \e[1;97m\e[4;37mA\e[0mll drives above.\r\n" ;
    echo -en "\t\e[1;97mS\e[0m)  Select Directory to back up to a \e[1;97m\e[4;37mS\e[0mingle drive\r\n" ;
    echo -en "\t\e[1;97mD\e[0m)  Select \e[1;97m\e[4;37mD\e[0mirectory to back up to all drives.\r\n"
    echo -en "\t\e[1;97mF\e[0m)  Select Directory or \e[1;97m\e[4;37mF\e[0mile to back up into any other Directory.\r\n\n"
    echo -en "\t\e[1;97mQ\e[0m)  \e[1;97m\e[4;37mQ\e[0muit script\r\n\n"

    echo -en "\tIf you would like to select more than one drive, enter the number \n"
    echo -en "\t  from the list above, separated by spaces, in any sequence. \n"
    echo -en "\t  'A' will cause all numbers entered to be ignored. \n"
    echo -en "\t  The script will run all synchronization in the sequence you've provide.\n\r\n"
    echo -en "\tSelect: ${NUM_SEQUENCE}, A, S, L, or F: " ;

    IFS= read -r OPT &>/dev/null 2>&1 ; IFS=' ' read -r -a OPT_ARRAY <<< "$OPT"
    #   Look in the array and see if the user entered an A in the listing, this entry overrides any individual drive selection. 
    if [[ -n "${opt1}" ]] || [[ -n "${opt2}" ]] ; 
        then echo -en "The 'A' option was detected in the selection. Switching to sycing " ; printf '\e[1;97m\e[4;37mA\e[0m';echo "ll drives." ; OPT_ARRAY=("A") ; 
    fi

    for eachDrive in "${!OPT_ARRAY[@]}"; do 
        case "${OPT_ARRAY[eachDrive]}" in
            1 )  
                zenity --notification --text="Attempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[0]}" ; 
                echo -e " \033]0;Syncing from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[0]}\007" ;
                zenity --notification --text " \t Attempting to run rsync.\r\nAttempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[0]}" ; 
                if ! TAB_OVER rsync -rltH -S -pgo --stats -D --numeric-ids --no-i --info=name0 --info=progress2 -- "${THIS_DRIVE_PATHS}/" "${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" 2>&1 ; then EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" ; fi
                zenity --notification --text "rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[0]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" ; 
                
                echo "$(date +%m-%d-%Y_%H%M) --> rsync to ${ALL_DRIVES_PATHS[0]} exit status: Code: ${EXIT_CODE} - ${REASON}" |& tee -a "${RSYNC_LOG}" &>/dev/null;;
                
            #-----------------------

            [2-"${COUNT_FILES}"] )  
                zenity --notification --text="Attempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" ; 
                echo -e " \033]0;Syncing from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}\007" ;
                zenity --notification --text " \t Attempting to run rsync.\r\nAttempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" ; 
                if ! TAB_OVER rsync -rltH -S -pgo --stats -D --numeric-ids --no-i --info=name0 --info=progress2 -- "${THIS_DRIVE_PATHS}/" "${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" 2>&1 ; then EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" ; fi
                zenity --notification --text "rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" ; 
                
                echo "$(date +%m-%d-%Y_%H%M) --> rsync to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]} exit status: Code: ${EXIT_CODE} - ${REASON}" |& tee -a "${RSYNC_LOG}" &>/dev/null;;
                
            #-----------------------

            "A"|"a" ) 
                for i in $(seq 1 "${COUNT_FILES}"); do zenity --notification --text "Attempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[$i]}" ; echo -ne " \033]0;syncing from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[$i]}\007" ;
                echo -e " \033]0;Syncing from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}\007" ;
                zenity --notification --text " \t Attempting to run rsync.\r\n Attempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" ; 
                START_CURS_DANCE ; if ! TAB_OVER rsync -rltH -S -pgo --stats -D --numeric-ids --no-i --info=name0 --info=progress2 -- "${THIS_DRIVE_PATHS}/" "${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" 2>&1 ; then EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" ; fi ; FINIS_CURS_DANCE ;
                zenity --notification --text "rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" ; 
                echo -e "$(date +%m-%d-%Y_%H%M) --> rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" |& tee -a "${RSYNC_LOG}" &>/dev/null ; 
                done ;;
            
            #-----------------------
            
            "S"|"s" ) 
                unset SINGLE_ALL_HOST ;
                SINGLE_ALL_HOST=$(zenity --file-selection --title="Select a directory for syncing to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" --directory --filename="${MEDIA_PATH}/${PRIME_SUDOER}") &> /dev/null;
                if [[ $(( COUNT_FILES + 1 )) -gt 1 ]] ; then
                    printf " \t%s" "Select one drive, 1-${COUNT_FILES}, from the drive choices above:" ; 
                    read -r DRIVE_SEL ;
                    #   Terminal title change
                    echo -e " \033]0;Syncing from ${SINGLE_ALL_HOST} to ${DRIVE_SEL}\007" ;
                    zenity --notification --text " \t Attempting to run rsync.\r\n Attempting to run rsync from ${SINGLE_ALL_HOST} to ${DRIVE_SEL}" ; 
                    if ! TAB_OVER rsync -rltH -S -pgo --stats -D --numeric-ids --no-i --info=name0 --info=progress2 -- "${SINGLE_ALL_HOST}/" "${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" 2>&1 ; then EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" ; fi
                    zenity --notification --text "rsync from ${SINGLE_ALL_HOST} to ${DRIVE_SEL} exit status:\nCode: ${EXIT_CODE} - ${REASON}" ;
                else 
                    until [[ "$yn" = "n" ]] || [[ "$yn" = "N" ]] || [[ "$yn" = "y" ]] || [[ "$yn" = "Y" ]]; do 
                        echo -en " \tOnly one drive detected.\n\r\tDo you wish to copy this folder to ${ALL_DRIVES_PATHS[0]}. Y/N? ";  
                        read -r yn ; 
                        case $yn in 
                            "Y"|"y" ) echo -e " \r\nThank you. Continuing..." ; 
                                zenity --notification --text " \t Attempting to run rsync.\r\n Attempting to run rsync from ${SINGLE_ALL_HOST} to ${ALL_DRIVES_PATHS[0]}" ; 
                                if ! TAB_OVER rsync -rltH -S -pgo --stats -D --numeric-ids --no-i-r --info=name0 --info=progress2 -- "${SINGLE_ALL_HOST}/" "${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" 2>&1 ; then EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" ; fi
                                zenity --notification --text "rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[0]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" ;; 
                            "N"|"n" ) echo OK. Exiting... ; pause ; exit ;; 
                            *) echo "Selection invalid! Try again." ; pause ;
                        esac ; 
                    done
                        echo -e "$(date +%m-%d-%Y_%H%M) --> rsync to ${DRIVE_SEL}, exit status: Code: ${EXIT_CODE} - ${REASON}" |& tee -a "${RSYNC_LOG}" &>/dev/null ;
                fi ;;

            #-----------------------

            "D"|"d" ) 
                unset SINGLE_DIR_HOST ;
                SINGLE_DIR_HOST=$(zenity --file-selection --title="Select a directory for syncing to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" --directory --filename="${MEDIA_PATH}/${PRIME_SUDOER}") &> /dev/null;
                for i in $(seq 1 "${COUNT_FILES}"); do 
                    zenity --notification --text "Attempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}/" ; 
                    echo -ne " \033]0;syncing from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}/\007" ;
                    if ! TAB_OVER rsync -vrltH -S -pgo --stats -D --numeric-ids --no-i-r --info=name0 --info=progress2 -- "${SINGLE_ALL_HOST}/" "${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" 2>&1 ; then  EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" ; fi
                    zenity --notification --text "rsync from ${SINGLE_DIR_HOST} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" ;                            
                    echo -e "$(date +%m-%d-%Y_%H%M) --> rsync to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]} exit status: Code: ${EXIT_CODE} - ${REASON}" |& tee -a "${RSYNC_LOG}" &>/dev/null ;
                done ;;

            #-----------------------

            "F"|"f" ) 
                unset SINGLE_HOST ;
                count=1 ; fod="" ; while [[ -z "${NEW_MOUNT_PATH}" ]] ; do
                printf '\n\n\r\t%s' "Do you wish to select a (D))irectory or (F)ile to sync [D/F]? " ; 
                read -r fod ; printf '\r\n' ; case ${fod} in 
                    "D"|"d" ) 
                        while [[ -z "${SINGLE_HOST}" ]] ; do 
                            printf '\n\n\r\t%s' "Select Directory: " ; 
                            SINGLE_HOST=$(zenity --file-selection --title="Select a directory for syncing" --directory --filename="/home/${PRIME_SUDOER}/") &> /dev/null ; 
                        done ;
                        while [[ -z "${NEW_MOUNT_PATH}" ]] ; do 
                            printf '\n\n\r\t%s' "Select Directory: " ; 
                            NEW_MOUNT_PATH="$(zenity --file-selection --filename="/home/${PRIME_SUDOER}/" --directory --title="Select any directory on your computer for syncing to")" ; 
                        done 
                        ;;
                    "F"|"f" ) 
                        while [[ -z "${SINGLE_HOST}" ]] ; do 
                            printf '\n\n\r\t%s\n' "Select File: " ; 
                            SINGLE_HOST=$(zenity --file-selection --title="Select a single file for syncing" --filename="/home/${PRIME_SUDOER}/") &> /dev/null ; 
                        done ;
                        while [[ -z "${NEW_MOUNT_PATH}" ]] ; do 
                            printf '\n\n\r\t%s\n' "Select Directory: " ; 
                            NEW_MOUNT_PATH="$(zenity --file-selection --filename="/home/${PRIME_SUDOER}/" --directory --title="Select any directory on your computer for syncing to")" ; 
                        done 
                        # if [[ -n ${NEW_MOUNT_PATH} ]] ; then echo "${NEW_MOUNT_PATH}" ; break ; fi 
                        ;;
                    *) if [[ ${count} -eq 1 ]] ; then echo -n "Again... " ; count=$(( count + 1 )) ;  else echo -n "Once again... Try number #${count}. " ; fi ; count=$(( count + 1 )) ;
                esac ; 
                done ; zenity --notification --text "Attempting to run rsync from ${SINGLE_HOST} to ${NEW_MOUNT_PATH}/" ; 
                
                echo -ne " \033]0;syncing from ${SINGLE_HOST} to ${NEW_MOUNT_PATH}/\007" ; START_CURS_DANCE "${SINGLE_HOST}" "${NEW_MOUNT_PATH}" ;
                if ! TAB_OVER rsync -lauPh --info=name0 -- "${SINGLE_ALL_HOST}/" "${NEW_MOUNT_PATH}" 2>&1 ; then  EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" ; fi
                zenity --notification --text "rsync from ${SINGLE_HOST} to ${NEW_MOUNT_PATH} exit status:\nCode: ${EXIT_CODE} - ${REASON}" ;                            
                echo -e "$(date +%m-%d-%Y_%H%M) --> rsync ${SINGLE_HOST} to ${NEW_MOUNT_PATH} exit status: Code: ${EXIT_CODE} - ${REASON}" |& tee -a "${RSYNC_LOG}" &>/dev/null ;;

            "Q"|"q" ) exit ;;

            #-----------------------

            * ) printf '%s' "Selection invalid! Try again, " ; printf '\t%s\n' "$(read -srn1 -p 'Press any key to continue...')"; ;;

        esac
    done
done
