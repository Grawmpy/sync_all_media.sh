#!/usr/bin/bash 
# shellcheck enable=require-variable-braces
###################################################################################################################################################
#
#    Sync files and directories from a selected media source to all or a select single media destination.       
#                                                                                                 
#    Creation : 30 April 2023                                                                      
#    Modify Date : 17 March 2024    
#    Production version : 4.3.1a                                                    
#                                                                                                                       
#    After host drive selection the script looks at the other attached peripherals to see if any drives 
#    are large enough to contain the entire backup in a one-to-one backup only.             
#                                                                                                 
###################################################################################################################################################
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
###################################################################################################################################################

#---- for debug ----- 
#set -x  
#--------------------- 
set -e

### Error trap to show which line the error occurred using awk with the line and the two lines before and after
err() {
    echo -e "Error occurred:\n"
    echo '********************'
    echo -e '>>> shows line containing error.\n'
    awk 'NR>L-4 && NR<L+4 { printf "\n%-5d%3s%s\n",NR,(NR==L?">>>":""),$0 }' L="${1}" "${0}"
    pause
}
trap 'err $LINENO' ERR

##########################################################START#########################################################
### Prints text in a pretty flourescent green that stands out against the black
print_header() {
  echo -e "\n\e[1;32m$1\e[0m"
}

###################################################################################################################################################
#   Check if yad is installed.
if which yad &>/dev/null ; 
    then 
        yadzen=yad ; 
    else 
        yadzen=zenity ; 
fi

###################################################################################################################################################
#   Get the logged in user's username 
if [[ $( whoami ) = "root" ]] 
    then 
        PRIME_SUDOER=${SUDO_USER} 
    else 
        PRIME_SUDOER=$( whoami ) 
fi

###################################################################################################################################################
#   Create a pause function that works similar to the windows version 
if ! which pause &>/dev/null ; then
pause()( 
    printf '%s\n'  "$(read -rsn1 -p 'Press any key to continue...')" 
) 
fi

###################################################################################################################################################
#   Set the pathway to the /media directory 
MEDIA_PATH="/media/${PRIME_SUDOER}" 

###################################################################################################################################################
#   Increase the terminal window size to 110x40 
printf '\033[8;40;110t' 

###################################################################################################################################################
#   DEFINE THE LOG FILE FOR RSYNC TO USE TO  
if [[ ! -d "/home/${PRIME_SUDOER}/rsync_logs" ]] 
    then 
        mkdir "/home/${PRIME_SUDOER}/rsync_logs" 
    else 
        RSYNC_LOG="$(touch "/home/${PRIME_SUDOER}/rsync_logs/rsync_$(date +%m-%d-%Y_%H%M).log")" 
fi 

###################################################################################################################################################
#   The variable host_drive_sel below will be blank if anything outside of the media path is selected, or if the request is cancelled. 
#   Both will give an error of a blank variable.  
#   While the variable is not set, repeat the request until it's filled, if not, exit. 
GET_HOST() { 
unset host_drive_sel host_name drive_path 
local host_drivhich pause e_sel host_name 
export drive_path 

while  [[ -z ${host_name} ]] ; do 
    while [[ -z ${host_drive_sel} ]] ; do 
        if ! host_drive_sel=$(${yadzen} --file-selection --title="Select a media drive" --directory --filename="${MEDIA_PATH}/") 
            then return 1 
        fi 
    done 
    host_name=$(basename "${host_drive_sel}") 
done 
 
drive_path="${MEDIA_PATH}/${host_name}" 

if ! cd "${host_drive_sel}" 
    then echo -ne "Changing directory to ${drive_path} failed. Attempting another try." 
fi 

check="$(basename "${PWD}")" 

if [[  "${check}" == "${host_name}"  ]] 
    then    echo -e "${drive_path}\n" 
            return 0 
    else    return 1 
fi 
} ;

###################################################################################################################################################
#   This function verifies whether a function has been loaded into memory and is available for use in this script.  
#   0 - found and ready, 1 - Not available (error) 
VERIFY_FUNCTION(){ 
    [[ "$(LC_ALL=C type -t "${1:-}")" && "$(LC_ALL=C type -t "${1:-}")" == function ]] ;
} 

###################################################################################################################################################
#   Define the errorcodes produced by rsync 
TRANSLATE_ERRORCODE(){ 
X_CODE="${1:-}";
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
        *)     CODE="Unknown or Invalid exit code sent. Code: ${X_CODE} " ;; 
    esac 
    printf 'Exit %s: %s\n' "${X_CODE}" "${CODE}" 
    return "${X_CODE}" 
} 

###################################################################################################################################################
#   Get the number of characters needed to create the underline section in the menu 
#   The character doesn't matter here, the variable is merely for width and is for  a width placeholder only 
UNDERLINE(){ 
    unset input output 
    local input output 
    input="$(( $1 + 3 ))" 
    output=$( 
        for i in $( seq 0 ${input} ); do 
            echo -n "_" ;  
        done 
    ) 
    echo "${output}" 
 } 

###################################################################################################################################################
#   Run rsync from the gathered data and use a Waiting animation while running
RUN_RSYNC_PROG() { 
    unset RSYNC_EXCLUDES host host find_drive tfs tdp rt ru ra 
    declare RSYNC_EXCLUDES host host find_drive tfs tdp rt ru ra  
    RSYNC_EXCLUDES=( '--exclude=\".Trash-1000\"' '--exclude=\"lost+found\"' '--exclude=\"timeshift\"' '--exclude=\"System Volume Information\"' '--exclude=\"\$RECYCLE.BIN\"' )

    host="${1:-}" 
    dest="${2:-}" 

    find_drive="$(df | grep "$(basename "${dest}")")"

    if ! tdp="$(echo "${find_drive}" | awk '{ print $6 }')" ; then LOG_ECHO "Error declaring or populating the variable 'tdp'" ; fi 

    if ! tfs="$(echo "${find_drive}" | awk '{ print $1 }')" ; 
        then 
            LOG_ECHO "Error declaring or populating the variable  'tfs'" ; 
    fi 

    tdt=$(( "$(echo "${find_drive}" | awk '{ print $2 }' | sed "s/[^0-9]*//g" )" * 1000 ))
    
    if ! rt="$( numfmt --to=si --suffix="b" "${tdt}")" ; 
        then 
            LOG_ECHO "Error declaring or populating the variable 'rt'" ; 
    fi 
    
    tdu=$(( "$(echo "${find_drive}" | awk '{ print $3 }' | sed "s/[^0-9]*//g" )" * 1000 ))
    
    if ! ru="$( numfmt --to=si --suffix="b" "${tdu}")" ; 
        then 
            LOG_ECHO "Error declaring or populating the variable 'ru'" ; 
    fi 
    
    tda=$(( "$(echo "${find_drive}" | awk '{ print $4 }' | sed "s/[^0-9]*//g" )" * 1000 ))
    
    if ! ra="$( numfmt --to=si --suffix="b" "${tda}")" ; 
        then LOG_ECHO "Error declaring or populating the variable 'ra'" ; 
    fi 
    
    tput civis ; 

    dots=5 
    
    rsync -ahlmqr --numeric-ids --progress --fsync --mkpath --log-file="${RSYNC_LOG}" "${RSYNC_EXCLUDES[@]}" --log-file-format="%t: %o %f %b" -- "${host}/" "${dest}" &
    
    my_pid=$! 
    
    clear 
    
    echo -e "\a\n\n\r" 
    echo -en "\t\e[0mHost Drive: \e[1;32m${DRIVE_NAME}\e[0m\n\t\t      Location: \e[2;37m${THIS_FILESYSTEMS}\e[0m Total: \e[2;37m${READABLE_TOTAL}\e[0m Used: \e[2;37m${READABLE_IUSED}\e[0m Avail: \e[2:37m${READABLE_AVAIL}\e[0m\r\n" 
    echo -en "\tDestination: \e[1;32m${tdp}\e[0m\n\t\t      Location: \e[2;37m${tfs}\e[0m Total: \e[2;37m${rt}\e[0m Used: \e[2;37m${ru}\e[0m Avail: \e[2;37m${ra}\e[0m \r\n"
    echo -en '\n\n\n\t' 
    echo -e "rsync is now running... Please wait. \n\tThe menu will reappear when the program is finished." 
    tput sc 

    #IFS='[;' read -rsd R -p $'\e[6n' _ ROW COL ; tput cup "$ROW" "$COL" 
    while [ -d /proc/"${my_pid}" ] ; do
        unset i ; printf '\r\tWorking\033[K' 
        for (( i=1 ; i<="${dots}" ; i++ )) ; do 
            printf '%s' "."; sleep 0.5 ; 
        done 
        printf '\r\tWorking\033[K' 
        for (( i=1 ; i<="${dots}" ; i++ )) ; do 
            printf '%s' " "; 
            sleep 0.5 ; 
        done 
        tput rc 
    done 

    wait "${my_pid}" ; 
    errorcode=$? 
    reason=$(TRANSLATE_ERRORCODE "${errorcode}") 
    echo "${reason}" ; tput cvvis ; return "${errorcode}" 
} 


###################################################################################################################################################
#   Filter the entered menu selection and remove any spaces and doubled characters, looks for 'A' and removes numbers if found
CHK_A_OPT(){ 
    unset input0 input1 output0 
    declare input0 input1 contr_char 
    declare -i chkinput0 
    declare -ax output0 
    contr_char='A' 
    if [[ -z "${1:-}" ]] ; 
        then 
            return 1 ; 
    fi 
    #   Convert all letters to upper case, trim spaces, remove duplicates, trim new line char
    input0=$(echo "${1:-^^}" | tr -d ' ' | sed 's/./&\n/g'  | perl -ne '$H{$_}++ or print' | tr -d '\n' ) 
    #   Count the numbers of characters passed to the function, if only one here echo and return success 
    if [[ "${#input0}" -eq 1 ]] ; 
        then 
            echo "${input0}" ; 
            return 0 ; 
    fi 
    # Recount to see if the control character is present after removing dupes 
    chkinput0="$( echo "${input0}" | grep -c "${contr_char}" )" 

    #   If yes remove all numeric digits from the list. If no, keep everything as is  
    if [[ "${chkinput0}" -gt 0 ]] ; then input1="${input0[*]//[0-9]/}" ; fi 
        #   Count the number of characters left after filtering 
        #   If there is only one character left, no need to loop, echo the character and return success 
        if [[ "${#input1}" -eq 1 ]] ; then echo "${input1}" ; return 0 ; fi 
    if [[ -n ${input1} ]] ; then count=$(( "${#input1}" -1 )) 
        for each in $( seq 0 ${count} ) ; do output0+=("${input1:${each}:1}") ; done 
        else count=$(( "${#input1}" -1 )) ; for each in $( seq 0 ${count} ) ; do output0+=("${input0:${each}:1}") ; done 
    fi 
    #   Return the array with success 
    echo "${output0[@]}" 
    return 0 
}; 

###################################################################################################################################################
#   Start host drive data gathering and variable assignment
#   Check and run the function to do the host drive selection.
if VERIFY_FUNCTION GET_HOST ; 
    then 
        if ! DRIVE_NAME=$(GET_HOST) ; 
            then 
                LOG_ECHO "GET_HOST function failed to launch." ; 
                pause ; 
                exit ; 
        fi ; 
fi 

###################################################################################################################################################
#   Check to see if a windows os partition is connected to keep it from the drives found in the search. 
#   The OS drive is always on the same physical drive as the "reserved partition" and it is always the 
#   partition immediately preceeding the OS. Always. If this partition is not found then most likely it 
#   is not a Windows OS drive. I needed a surefire way to recognize a Windows OS drive and this was the 
#   only way to get it 100% of the time.
#
#   This statement searches with fdisk first for 'Microsoft reserved' type partition to find the drive with the OS; 
declare RECOV_PARTITION=$(sudo fdisk -l | grep "Microsoft reserved" | awk '{print $1}') ;
#   Comment out below if you do not want the windows drive change to "unmount=1"
unmount=0
unset FIND_WIN_OS RECOV_PARTITION DRIVE_OS_COMPARE 
#   If the "reserved drive" is not found then this dismounting section is bypasssed as a Windows OS drive was not found. Good for you!!
if [ -n ${RECOV_PARTITION} ] 
    then
#   Moves right past first five charcters from the output ("/dev/") echoing only the next 3 characters (sd?, nvm, dis...) 
    DRIVE_OS_COMPARE="${RECOV_PARTITION:5:3}" 
    FIND_WIN_OS="$(sudo fdisk -l | grep "${DRIVE_OS_COMPARE}" | grep "Microsoft basic data" | awk '{print $1}')"
    # Evaluates the statement below to find the partition where the OS is installed by looking for the drive with the ntfs flag which will contain the OS.
    if [[ -n ${FIND_WIN_OS} ]]
        then  
        #   Using the infomation from above leads us to the ntfs partition of the drive containing the Windows OS. 
        #   eval sudo fdisk -l | grep "${DRIVE_OS_COMPARE}" | grep "Microsoft basic data" | grep -v '/media' | awk '{print $1}' &>/dev/null 
        #   Looks to see if the drive is mounted, if it is, unmounts.
            if findmnt "${FIND_WIN_OS}" &>/dev/null 2>&1
                then
                    if [[ "${unmount}" -eq 0 ]] 
                        then 
                            sudo umount -f "${FIND_WIN_OS}"  &>/dev/null 2>&1
                    fi 
            fi
    fi 
fi


UNMOUNT_WIN() { 
########################################
# For dual boot users allow Windows drive 
declare FIND_WIN_OS FIND_WIN_REC WIN_OS_DRIVE RECOV_PARTITION DRIVE_OS_COMPARE ;
unset FIND_WIN_OS FIND_WIN_REC WIN_OS_DRIVE RECOV_PARTITION DRIVE_OS_COMPARE ;
declare -a ALL_DRIVES_PATHNAMES=() 
# As far as I can tell the only way this will not find a Windows OS is if someone manually 
# changes the entire partition from the installation drive to another drive on the system.
# In that case the variable will come up blank. With evarything involved in doing this, this scenario is almost non-existent.
# "Microsoft reserved" is the readable name for the 'msftres' flag always placed right before the Windows OS drive at installation. 
# "Microsoft basic data" is the readable name for the 'msftdata' flag used for all ntfs formatted drives
FIND_WIN_REC=$(sudo fdisk -l | grep "Microsoft basic data" | awk '{print $1}') ; # Find the reserved drive flag. This is always with the OS on the same drive.
# remove ("/dev/"); echoing the next 3 characters (sd?, nvm, dis...) 
# this action Narrows down search and eliminates backup drives formatted as ntfs
WIN_OS_DRIVE="${FIND_WIN_REC:5:3}" 
FIND_WIN_OS="$(sudo fdisk -l | grep "${WIN_OS_DRIVE}" | grep "Microsoft basic data" | grep -v "/media" | awk '{print $1}') &>/dev/null ; )"

if RECOV_PARTITION=$(sudo fdisk -l | grep "Microsoft reserved" | awk '{print $1}') ; then
#   Moves right past first five charcters from the output ("/dev/") echoing only the next 3 characters (sd?, nvm, dis...) 
    DRIVE_OS_COMPARE="${RECOV_PARTITION:5:3}" 
    if eval sudo fdisk -l | grep "${DRIVE_OS_COMPARE}" | grep "Microsoft basic data" | awk '{print $1}' &>/dev/null 
        then  
        #   Using the infomation from above leads us to the ntfs partition of the drive containing the Windows OS. 
        FIND_WIN_OS="$(sudo fdisk -l | grep "${DRIVE_OS_COMPARE}" | grep "Microsoft basic data" | grep -v '/media' | awk '{print $1}')" &>/dev/null 
            if findmnt "${FIND_WIN_OS}" &>/dev/null 2>&1
                then
                    sudo umount -f "${FIND_WIN_OS}"  &>/dev/null 2>&1
            fi
    fi 
fi
}

declare THIS_FILESYSTEMS READABLE_TOTAL READABLE_IUSED READABLE_AVAIL THIS_DRIVE_PATHS
### Filesystem information for selected host drive
declare THIS_FILESYSTEMS=$(df | grep "${DRIVE_NAME}" | awk '{ print $1 }') ;
### Total storage space on the host drive
READABLE_TOTAL="$( echo $(( $(df | grep "${DRIVE_NAME}" | awk '{ print $2 }' | sed "s/[^0-9]*//g" ) * 1000  )) | numfmt --to=si --suffix="b" "$@")" ;
### Total drive spaced used
READABLE_IUSED="$( echo $(( $(df | grep "${DRIVE_NAME}" | awk '{ print $3 }' | sed "s/[^0-9]*//g" ) * 1000  )) | numfmt --to=si --suffix="b" "$@")" ;
### Total drive space used
READABLE_AVAIL="$( echo $(( $(df | grep "${DRIVE_NAME}" | awk '{ print $4 }' | sed "s/[^0-9]*//g" ) * 1000  )) | numfmt --to=si --suffix="b" "$@")" ;
### Pathway to the selected host drive
THIS_DRIVE_PATHS=$(df | grep "${DRIVE_NAME}" | awk '{ print $6 }')

mapfile -t FOUND_DRIVES_TOTAL < <( df  | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $2 }' ) ;  

###################################################################################################################################################
#   ----------------------------------------------------------- START DRIVE ARRAY VALUES ---------------------------------------------------------- 
#   START COLLECTION OF ARRAY DATA FOR ALL ATTACHED MEDIA DRIVES 
#   Load all the filesystems into the variable ALL_FILESYSTEMS then compare to see if the destination drive is large enough to handle a one to one backup. 
unset TEMP_AFS ALL_FILESYSTEMS ; declare -a TEMP_AFS ALL_FILESYSTEMS ; 
    mapfile -t TEMP_AFS < <( df | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $1 }' ; ) ;
    for i in "${!TEMP_AFS[@]}" ; do if [[ ${THIS_DRIVE_IUSED} -lt "${FOUND_DRIVES_TOTAL[i]}" ]] ; then ALL_FILESYSTEMS+=("${TEMP_AFS[i]}"); fi ; done 
#   Load all the drive totals into the variable ALL_DRIVE_TOTALS then compare to see if the destination drive is large enough to handle a one to one backup. ;
unset TEMP_ADT ALL_DRIVE_TOTALS READABLE_ALL_TOTALS ; declare TEMP_ADT ALL_DRIVE_TOTALS READABLE_ALL_TOTALS ;
    mapfile -t TEMP_ADT < <( df  | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $2 }' ; ) ; 
    for i in "${!TEMP_ADT[@]}" ; do if [[ ${THIS_DRIVE_IUSED} -lt "${FOUND_DRIVES_TOTAL[i]}" ]] ; then ALL_DRIVE_TOTALS+=("${TEMP_ADT[i]}"); fi ; done ;
    for i in "${!ALL_DRIVE_TOTALS[@]}"; do if ! [[ "${ALL_DRIVE_TOTALS[i]}" -eq 0 ]] ; then READABLE_ALL_TOTALS+=("$( echo $(( ALL_DRIVE_TOTALS[i] * 1000  )) | numfmt --to=si --suffix="b" "$@")") ; fi ; done ;
#   Load all the drive used space into the variable ALL_DRIVE_IUSED then compare to see if the destination drive is large enough to handle a one to one backup. ;
unset TEMP_ADI ALL_DRIVE_IUSED READABLE_ALL_IUSED ; declare -a TEMP_ADI ALL_DRIVE_IUSED READABLE_ALL_IUSED ; 
    mapfile -t TEMP_ADI < <( df | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $3 }' ; ) ;
    for i in "${!TEMP_ADI[@]}" ; do if [[ ${THIS_DRIVE_IUSED} -lt "${FOUND_DRIVES_TOTAL[i]}" ]] ; then ALL_DRIVE_IUSED+=("${TEMP_ADI[i]}"); fi ; done ;
    for i in "${!ALL_DRIVE_IUSED[@]}"; do [[ ! "${ALL_DRIVE_IUSED[i]}" -eq 0 ]] && READABLE_ALL_IUSED+=("$( echo $(( ALL_DRIVE_IUSED[i] * 1000  )) | numfmt --to=si --suffix="b" "$@")") ; done ;
#   Load all the drive used space into the variable ALL_DRIVES_AVAIL then compare to see if the destination drive is large enough to handle a one to one backup. ;
unset TEMP_ADA ALL_DRIVES_AVAIL READABLE_ALL_AVAIL ; declare -a TEMP_ADA ALL_DRIVES_AVAIL READABLE_ALL_AVAIL ; 
    mapfile -t TEMP_ADA < <( df | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $4 }' ; ) ; 
    for i in "${!TEMP_ADA[@]}" ; do if [[ ${THIS_DRIVE_IUSED} -lt "${FOUND_DRIVES_TOTAL[i]}" ]] ; then ALL_DRIVES_AVAIL+=("${TEMP_ADA[i]}"); fi ; done ;
    for i in "${!ALL_DRIVES_AVAIL[@]}"; do [[ ! "${ALL_DRIVES_AVAIL[i]}" -eq 0 ]] && READABLE_ALL_AVAIL+=("$( echo $(( ALL_DRIVES_AVAIL[i] * 1000  )) | numfmt --to=si --suffix="b" "$@")") ; done ;
###################################################################################################################################################
#   Kept for inclusivity 
###################################################################################################################################################
#   Load all the drive used percentage into the variable ALL_DRIVE_PCENT then compare to see if the destination drive is large enough to handle a one to one backup. 
#unset TEMP_PCT ALL_DRIVE_PCENT ; declare -a TEMP_PCT ALL_DRIVE_PCENT ; if [[ ${isWindowsPartition} ]] ; 
#    then mapfile -t TEMP_PCT < <( df  | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $5 }' ; ) ;
#    else mapfile -t TEMP_PCT < <( df | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $5 }' ; ) ; fi 
#    for i in "${!TEMP_PCT[@]}" ; do if [[ ${THIS_DRIVE_IUSED} -lt "${FOUND_DRIVES_TOTAL[i]}" ]] ; then ALL_DRIVE_PCENT+=("${TEMP_PCT[i]}"); fi ; done ;
###################################################################################################################################################
#   Load all the drive paths into the variable ALL_DRIVES_PATHS then compare to see if the destination drive is large enough to handle a one to one backup. ;
unset TEMP_ADP ALL_DRIVES_PATHS ALL_DRIVES_PATHNAMES ; declare -a TEMP_ADP ALL_DRIVES_PATHS ALL_DRIVES_PATHNAMES ; if [[ ${isWindowsPartition} ]] ; 
    then mapfile -t TEMP_ADP < <( df  | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $6 }' ; ) ;
    else mapfile -t TEMP_ADP < <( df | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $6 }' ; ) ; fi ;
    for i in "${!TEMP_ADP[@]}" ; do if [[ ${THIS_DRIVE_IUSED} -lt "${FOUND_DRIVES_TOTAL[i]}" ]] ; then ALL_DRIVES_PATHS+=("${TEMP_ADP[i]}"); fi ; done ;

mapfile -t ALL_DRIVES_PATHNAMES < <(  for i in "${!ALL_DRIVES_PATHS[@]}" ; do basename "${ALL_DRIVES_PATHS[i]}" | sed 's/\(.\{12\}\).*/\1.../' ; done ) ;

#   ----------------------------------------------------------- END drive ARRAY VALUES ------------------------------------------------------------ 
###################################################################################################################################################

###################################################################################################################################################
#   Count the number of files found
declare -i COUNT_FILES;        
COUNT_FILES="${#ALL_FILESYSTEMS[@]}"  
#   Count all the entries for each column
AFS_COUNT=${#ALL_FILESYSTEMS} 
#ADT_COUNT=${#ALL_DRIVE_TOTALS} 
#ADI_COUNT=${#ALL_DRIVE_IUSED} 
#ADA_COUNT=${#ALL_DRIVES_AVAIL} 
#PCT_COUNT=${#ALL_DRIVE_PCENT} 
#ADP_COUNT=${#ALL_DRIVES_PATHNAMES} 

if eval VERIFY_FUNCTION UNDERLINE ; then  
UNDER_FST=$(UNDERLINE "${AFS_COUNT}" ) 
UNDER_ADT=$(UNDERLINE 6  ) ; # "${ADT_COUNT}" ) 
UNDER_ADI=$(UNDERLINE 6  ) ; # "${ADI_COUNT}" ) 
UNDER_ADA=$(UNDERLINE 6  ) ; # "${ADA_COUNT}" ) 
UNDER_ADP=$(UNDERLINE 15 ) ; # "${ADP_COUNT}" ) 
# UNDER_PCT=$(UNDERLINE "${PCT_COUNT}") 
fi 
#   Write the number sequence of all available drives found, separated by a comma for selection menu (1, 2, 3, ...??)
unset NUM_SEQUENCE 
for i in $(seq 1 ${COUNT_FILES}); do 
    if [[ ${i} -ne ${COUNT_FILES} ]]
        then 
            NUM_SEQUENCE+=$(printf '%s' "${i}, ")
        else 
            NUM_SEQUENCE+=$(printf '%s' "${i}") 
    fi 
done 

#   Gather up all the available media drive data to place on the menu 
declare -a AVAIL_DRIVES ; mapfile -t AVAIL_DRIVES < <(  
    for EACH_DRIVE in "${!ALL_FILESYSTEMS[@]}"; do 
        printf "%-${#UNDER_ADP}s\t%-${#UNDER_FST}s\t%-${#UNDER_ADT}s\t%-${#UNDER_ADI}s\t%-${#UNDER_ADA}s\n" \
        "${ALL_DRIVES_PATHNAMES[EACH_DRIVE]}" "${ALL_FILESYSTEMS[EACH_DRIVE]}" "${READABLE_ALL_TOTALS[EACH_DRIVE]}" "${READABLE_ALL_IUSED[EACH_DRIVE]}" "${READABLE_ALL_AVAIL[EACH_DRIVE]}" ; 
    done ) 
    if [[ ${ALL_FILESYSTEMS[0]} == "" ]] ; then AVAIL_DRIVES[0]="No available drive found to accept backup" ; fi

#   Put everything together and run the program 
while true ; do 
#   Start loop to configure, print out menu and run rsync program 
    #clear 
    echo -e "\a\n\n\r" 
    #   List information for the host drive selected
    echo -en "  \tCurrent Drive: " ; echo -en "\t\e[1;32m$(basename "${DRIVE_NAME}")" ; echo -ne "\e[0m" ; echo -en "\e[2;37m(${THIS_FILESYSTEMS})\e[0m   Total: \e[2;37m${READABLE_TOTAL}\e[0m - Used: \e[2;37m${READABLE_IUSED}\e[0m - Avail: \e[2:37m${READABLE_AVAIL}\e[0m\r\n" 

    #   Print the heading with titles and underline each column heading 
    printf "\t\e[2;4;22m%-${#UNDER_ADP}s\e[0m\t\e[4;22m%-${#UNDER_FST}s\e[0m\t\e[4;22m%-${#UNDER_ADT}s\e[0m\t\e[4;22m%-${#UNDER_ADI}s\e[0m\t\e[4;22m%-${#UNDER_ADA}s\e[0m\n" "Drive name" "Location" "Total " "Used " "Available " 
    

    #   Combine data gathered of available drives and list them in this format (size is listed in Mb, Gb, Tb...):
    #   1)  <DriveName>            	/dev/sd??    	<total>     	<used>     	<avail>
    for i in $(seq 1 "${#AVAIL_DRIVES[@]}"); do 
        printf '\t\e[1;97m%s\e[0m'; echo -en "\e[1;32m"; echo -ne "${i}" ; echo -ne "\e[0m)" ; printf ' %s\n' "${AVAIL_DRIVES[$((i-1))]}"
    done 

    echo -en '\n\a' ; # Inset a space and toggle bell for notification

    # List options available other than entering the number from drive listing
    if [[ ${AVAIL_DRIVES[0]} != "No available drive found to accept backup" ]] ; then echo -en "\t\e[1;32m" ; echo -en "A" ; echo -ne "\e[0m)  Backup to \e[1;97m\e[4;37mA\e[0mll drives above.\r\n" ; fi
    if [[ ${AVAIL_DRIVES[0]} != "No available drive found to accept backup" ]] ; then echo -en "\t\e[1;32m" ; echo -en "S" ; echo -ne "\e[0m)  Select Directory to back up to a \e[1;97m\e[4;37mS\e[0mingle drive\r\n" ; fi
    if [[ ${AVAIL_DRIVES[0]} != "No available drive found to accept backup" ]] ; then echo -en "\t\e[1;32m" ; echo -en "D" ; echo -ne "\e[0m)  Select \e[1;97m\e[4;37mD\e[0mirectory to back up to all drives.\r\n" ; fi
    echo -en "\t\e[1;32m" ; echo -n "F" ; echo -ne "\e[0m)  Select Directory or \e[1;97m\e[4;37mF\e[0mile to back up into any other Directory.\r\n\n" 
    echo -en "\t\e[1;32m" ; echo -n "Q" ; echo -ne "\e[0m)  \e[1;97m\e[4;37mQ\e[0muit script\r\n\n" 
    # Instructions
    echo -en "\tIf more than one selection is entered, the script will run in the sequece provided\n\r\n" 
    if [[ ${AVAIL_DRIVES[0]} != "No available drive found to accept backup" ]] ; then echo -en "\t['A' = numbers will be ignored] \n" ; fi
    echo -en "\tSelection options: " ; echo -e "$( if [[ ${AVAIL_DRIVES[0]} != "No available drive found to accept backup" ]] ; then echo "${NUM_SEQUENCE}, A, S, D, " ; fi )F or Q \n" 
    echo -ne "\t\e[1;32mEnter any option from the list above: \e[0m" 
    unset OPT OPT_TMP OPT_ARRAY 
    #   Pause and wait for user selection entry....
    IFS= read -r OPT_TMP &>/dev/null 2>&1 
    #   After menu selection entry is done, run a function to filter out possible spaces and duplicate entries before
    #   checking for an 'A' entry which would override any number selection entered.
    #   This will take all those entries and convert them into an array that can be used by the case statement for each selection
    OPT_ARRAY=( "$(CHK_A_OPT "${OPT_TMP^^}")" ) 

    #   Start loop to process each menu selection option
    for eachDrive in "${!OPT_ARRAY[@]}" ; do  
    #   Process through each selection and 
        case "${OPT_ARRAY[eachDrive]}" in 

            [1-"${COUNT_FILES}"] ) 
                #   Announce activity 
                zenity --notification --text="Attempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" 
                #   Place a title on the terminal top 
                 echo -en "\e[1;32m;Syncing from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}\033]0\007;" 
                #  Start the rsync program 
                RUN_RSYNC_PROG "${DRIVE_NAME}" "${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" ; EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" 
                #   Announce error 
                zenity --notification --text "rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" 
                #   Echo status to log 
                clear
                echo -e "\t\e[1;36m${REASON}\e[0m" ;
            ;;  #   end case selection 
            
            "A"|"a" ) 
                for a in "${!ALL_DRIVES_PATHS[@]}" ; do  
                    zenity --notification --text "Attempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[a]}" 
                    #   Place a title on the terminal top 
                    echo -e " \033]0;Syncing from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[a]}\007" 
                    #  Start the rsync program 
                    RUN_RSYNC_PROG "${DRIVE_NAME}" "${ALL_DRIVES_PATHS[a]}" ; EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" 
                    #   Announce error 
                    zenity --notification --text "rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[a]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" 
                    #   Echo status to log 
                    clear
                    echo -e "\t\e[1;36m${REASON}\e[0m" ;
                done  
                ;;  #   end case selection 
                
            "S"|"s" ) 
                unset SINGLE_ALL_HOST 
                SINGLE_ALL_HOST=$(zenity --file-selection --title="Select a directory for syncing" --directory --filename="${MEDIA_PATH}/${PRIME_SUDOER}") &> /dev/null;
                if [[ $(( COUNT_FILES + 1 )) -gt 1 ]] 
                then 
                    printf " \t%s" "Select one drive, 1-${COUNT_FILES}, from the drive choices above:" 
                    read -r DRIVE_SEL 
                    #   Terminal title change 
                    echo -e " \033]0;Syncing from ${SINGLE_ALL_HOST} to ${DRIVE_SEL}\007" 
                    zenity --notification --text " \t Attempting to run rsync.\r\n Attempting to run rsync from ${SINGLE_ALL_HOST} to ${DRIVE_SEL}" 
                    #  Start the rsync program 
                    RUN_RSYNC_PROG "${SINGLE_ALL_HOST}" "${DRIVE_SEL}" ; EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" 
                    zenity --notification --text "rsync from ${SINGLE_ALL_HOST} to ${DRIVE_SEL} exit status:\nCode: ${EXIT_CODE} - ${REASON}" 
                else 
                    until [[ "${yn}" = "n" ]] || [[ "${yn}" = "N" ]] || [[ "${yn}" = "y" ]] || [[ "${yn}" = "Y" ]] ; do  
                        echo -en " \tOnly one drive detected.\n\r\tDo you wish to copy this folder to ${ALL_DRIVES_PATHS[0]}. Y/N? "; 
                        read -r yn 
                        case ${yn} in 
                            "Y"|"y" ) echo -e " \r\nThank you. Continuing..." 
                                zenity --notification --text " \t Attempting to run rsync.\r\n Attempting to run rsync from ${SINGLE_ALL_HOST} to ${ALL_DRIVES_PATHS[0]}" 
                                #  Start the rsync program 
                                RUN_RSYNC_PROG "${SINGLE_ALL_HOST}" "${ALL_DRIVES_PATHS[0]}" ; EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" 
                                zenity --notification --text "rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[0]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" 
                            ;; #   end case selection 
                            "N"|"n" ) echo OK. Exiting... ; pause ; exit 
                            ;; #   end case selection 
                            *) echo "Selection invalid! Try again." ; pause 
                            ;; #   end case
                        esac 
                    done 
                        clear
                    echo -e "\t\e[1;36m${REASON}\e[0m" ;
                fi  
           ;; #   end case selection 

            "D"|"d" ) 
                unset SINGLE_DIR_HOST 
                SINGLE_DIR_HOST=$(zenity --file-selection --title="Select a directory for syncing to ${ALL_DRIVES_PATHS[d]}" --directory --filename="${MEDIA_PATH}/${PRIME_SUDOER}") &> /dev/null 
                for d in "${!ALL_DRIVES_PATHS}"; do  
                    zenity --notification --text "Attempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[d]}/" 
                    echo -ne " \033]0;syncing from ${DRIVE_NAME} to ${ALL_DRIVES_PATHS[d]}/\007" 
                    #  Start the little dancing cursor 
                    RUN_RSYNC_PROG "${SINGLE_ALL_HOST}" "${ALL_DRIVES_PATHS[d]}" ; EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" 

                    #if ! TAB_OVER rsync "${RSYNC_FLAGS[@]}" -- "${SINGLE_ALL_HOST}/" "${ALL_DRIVES_PATHS[i]}" 2>&1 ; then EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" ; fi 
                    zenity --notification --text "rsync from ${SINGLE_DIR_HOST} to ${ALL_DRIVES_PATHS[d]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" ;     
                    clear                   
                    echo -e "\t\e[1;36m${REASON}\e[0m" ;
                done  
            ;; #   end case selection 

            "F"|"f" ) 
                unset SINGLE_HOST 
                count=1 ; fod="" ; while [[ -z "${NEW_MOUNT_PATH}" ]] ; do 
                printf '\n\n\r\t%s' "Do you wish to select a (D))irectory or (F)ile to sync [D/F]? " 
                read -r fod ; printf '\r\n' ; case ${fod^^} in 

                    "D|d" ) 
                        while [[ -z "${SINGLE_HOST}" ]] ; do  
                            printf '\n\n\r\t%s' "Select Directory: " 
                            SINGLE_HOST=$(zenity --file-selection --title="Select a directory for syncing" --directory --filename="/home/${PRIME_SUDOER}/") &> /dev/null 
                        done 
                        while [[ -z "${NEW_MOUNT_PATH}" ]] ; do  
                            printf '\n\n\r\t%s' "Select Directory: " 
                            NEW_MOUNT_PATH="$(zenity --file-selection --filename="/home/${PRIME_SUDOER}/" --directory --title="Select any directory on your computer for syncing to")" 
                        done  
                    ;; #   end case selection 

                    "F"|"f" ) 
                        while [[ -z "${SINGLE_HOST}" ]] ; do  
                            printf '\n\n\r\t%s\n' "Select File: " 
                            SINGLE_HOST=$(zenity --file-selection --title="Select a single file for syncing" --filename="/home/${PRIME_SUDOER}/") &> /dev/null 
                        done 
                        while [[ -z "${NEW_MOUNT_PATH}" ]] ; do  
                            printf '\n\n\r\t%s\n' "Select Directory: " 
                            NEW_MOUNT_PATH="$(zenity --file-selection --filename="/home/${PRIME_SUDOER}/" --directory --title="Select any directory on your computer for syncing to")" 
                        done  
                    ;; #   end case selection 

                    *) if [[ ${count} -eq 1 ]] ; then echo -n "Again... " ; count=$(( count + 1 )) ;  else echo -n "Once again... Try number #${count}. " ; fi ; count=$(( count + 1 )) 
                    ;; #   end case selection 

                esac 
                done ; zenity --notification --text "Attempting to run rsync from ${SINGLE_HOST} to ${NEW_MOUNT_PATH}/" 
            
                echo -ne " \033]0;syncing from ${SINGLE_HOST} to ${NEW_MOUNT_PATH}/\007" ; RUN_RSYNC_PROG "${SINGLE_HOST}" "${NEW_MOUNT_PATH}" 
                #  Start the little dancing cursor 
                RUN_RSYNC_PROG "${SINGLE_ALL_HOST}" "${NEW_MOUNT_PATH}" 
                #if ! TAB_OVER rsync "${RSYNC_FLAGS[@]}" -- "${SINGLE_ALL_HOST}/" "${NEW_MOUNT_PATH}" 2>&1 ; then EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" ; fi 
                zenity --notification --text "rsync from ${SINGLE_HOST} to ${NEW_MOUNT_PATH} exit status:\nCode: ${EXIT_CODE} - ${REASON}" ;   
                clear                     
                echo -e "\t\e[1;36m${REASON}\e[0m" ;
            ;; #   end case selection 

            "Q"|"q" ) exit 
            ;; #   end case selection 

            * ) clear ;
                printf '\t%s' "Invalid selection. Please try again. " ; 
                printf '\t%s\r\n' "$(read -srn1 -p 'Press any key to continue...')" ;
            ;; #   end case selection 

        #   end case
        esac 
    #   End loop to process each menu option
    done 

#   End loop to configure, print out selection menu and run rsync program 
done
