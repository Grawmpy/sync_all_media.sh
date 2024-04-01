#!/usr/bin/bash 

###################################################################################################################################################
#
#    Sync files and directories from a selected media source to all or a select single media destination.       
#                                                                                                 
#    Creation : 30 April 2023                                                                      
#    Modify Date : 17 March 2024    
#    Production version : 4.4                                                  
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
 

###################################################################################################################################################
#   Check if yad is installed.
if which yad &>/dev/null ; 
    then yadzen=yad ; 
    else yadzen=zenity ; 
fi

###################################################################################################################################################
#   Get the logged in user's username 
if [[ $( whoami ) = "root" ]] 
    then PRIME_SUDOER=${SUDO_USER} 
    else PRIME_SUDOER=$( whoami ) 
fi

###################################################################################################################################################
#   Create a pause function that works similar to the windows version 
pause()( printf '%s\n'  "$(read -rsn1 -p 'Press any key to continue...')" ) 

###################################################################################################################################################
#   Set the pathway to the /media directory 
MEDIA_PATH="/media/${PRIME_SUDOER}" 

###################################################################################################################################################
#   Increase the terminal window size to 110x40 
printf '\033[8;40;110t' 

###################################################################################################################################################
#   DEFINE THE LOG FILE FOR RSYNC TO USE TO  
if [[ ! -d "/home/${PRIME_SUDOER}/rsync_logs" ]] ; then mkdir "/home/${PRIME_SUDOER}/rsync_logs" ; fi 
RSYNC_LOG="$(touch "/home/${PRIME_SUDOER}/rsync_logs/rsync_$(date +%m-%d-%Y_%H%M).log")" 

###################################################################################################################################################
#   The variable host_drive_sel below will be blank if anything outside of the media path is selected, or if the request is cancelled. 
#   Both will give an error of a blank variable.  
#   While the variable is not set, repeat the request until it's filled, if not, exit. 
GET_HOST() { 
unset host_drive_sel host_name drive_path 
local host_drive_sel host_name 
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

if ! cd "${host_drive_sel}" ; then echo -ne "Changing directory to ${drive_path} failed. Attempting another try." ; fi 

check="$(basename "${PWD}")" 

if [[  "${check}" == "${host_name}"  ]] 
    then echo -e "${drive_path}\n" 
        return 0 
    else return 1 
fi 
} ;

###################################################################################################################################################
#   This function verifies whether a function has been loaded into memory and is available for use in this script.  
#   0 - found and ready, 1 - Not available (error) 
VERIFY_FUNCTION(){ [[ "$(LC_ALL=C type -t "${1:-}")" && "$(LC_ALL=C type -t "${1:-}")" == function ]] ; } 

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
    printf '"Error Code %s: \t%s\n' "${X_CODE}" "${CODE}" 
    return "${X_CODE}" 
} 

###################################################################################################################################################
#   Get the number of characters needed to create the underline section in the menu 
#   The character doesn't matter here, the variable is merely for width and is for  a width placeholder only 
UNDERLINE(){ 
    unset input output 
    local input output 
    input="$(( $1 + 3 ))" 
    output=$( for i in $( seq 0 ${input} ); do echo -n "_" ;  done ) 
    echo "${output}" 
 } 

###################################################################################################################################################
#   Run rsync from the gathered data and use a Waiting animation while running
RUN_RSYNC_PROG() { 
    unset RSYNC_EXCLUDES host host find_drive temp_drive_fsys temp_drive_path read_total read_iused read_avail 
    declare RSYNC_EXCLUDES host host find_drive temp_drive_fsys temp_drive_path read_total read_iused read_avail  
    RSYNC_EXCLUDES=( '--exclude=\".Trash-1000\"' '--exclude=\"lost+found\"' '--exclude=\"timeshift\"' '--exclude=\"System Volume Information\"' '--exclude=\"\$RECYCLE.BIN\"' )

    host="${1:-}" 
    dest="${2:-}" 

    find_drive="$(df | grep "$(basename "${dest}")")"

    if ! temp_drive_path="$(echo "${find_drive}" | awk '{ print $6 }')" ; then echo "Error declaring or populating the variable 'temp_drive_path'" | tee -a "${RSYNC_LOG}" ; fi 

    if ! temp_drive_fsys="$(echo "${find_drive}" | awk '{ print $1 }')" ; then echo "Error declaring or populating the variable  'temp_drive_fsys'" | tee -a "${RSYNC_LOG}" ; fi 
    
    if ! read_total="$( numfmt --to=si --suffix="b" "$(( "$(echo "${find_drive}" | awk '{ print $2 }' | sed "s/[^0-9]*//g" )" * 1000 ))" )" ; 
        then echo "Error declaring or populating the variable 'read_total'" | tee -a "${RSYNC_LOG}" ; 
    fi 
        
    if ! read_iused="$( numfmt --to=si --suffix="b" "$(( "$(echo "${find_drive}" | awk '{ print $3 }' | sed "s/[^0-9]*//g" )" * 1000 ))")" ; 
        then echo "Error declaring or populating the variable 'read_iused'" | tee -a "${RSYNC_LOG}" ; 
    fi 
        
    if ! read_avail="$( numfmt --to=si --suffix="b" "$(( "$(echo "${find_drive}" | awk '{ print $4 }' | sed "s/[^0-9]*//g" )" * 1000 ))")" ; 
        then echo "Error declaring or populating the variable 'read_avail'" | tee -a "${RSYNC_LOG}" ; 
    fi 
    
    tput civis ; 
    dots=5 

    rsync -ahlmqr --numeric-ids --fsync --mkpath --log-file="${RSYNC_LOG}" "${RSYNC_EXCLUDES[*]}" --log-file-format="%t: %o %f %b" -- "${host}/" "${dest}" &
    my_pid=$! 
    
    clear 
    
    echo -e "\a\n\n\r" 
    echo -en "\t Host Drive: ${DRIVE_NAME}\n\t\t      Location: \e[2;37m${THIS_FILESYSTEMS}\e[0m Total: \e[2;37m${READABLE_TOTAL}\e[0m Used: \e[2;37m${READABLE_IUSED}\e[0m Avail: \e[2:37m${READABLE_AVAIL}\e[0m\r\n" 
    echo -en "\tDestination: ${temp_drive_path}\n\t\t      Location: \e[2;37m${temp_drive_fsys}\e[0m Total: \e[2;37m${read_total}\e[0m Used: \e[2;37m${read_iused}\e[0m Avail: \e[2;37m${read_avail}\e[0m \r\n"
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
    if [[ "${chkinput0}" -gt 0 ]] ; 
        then input1="${input0[*]//[^0-9]/}" ; 
    fi 
        #   Count the number of characters left after filtering 
        #   If there is only one character left, no need to loop, echo the character and return success 
        if [[ "${#input1}" -eq 1 ]] ; then echo "${input1}" ; return 0 ; fi 
    if [[ -n ${input1} ]] ; then count=$(( "${#input1}" - 1 )) 
        for each in $( seq 0 ${count} ) ; do output0+=("${input1:${each}:1}") ; done 
        else count=$(( "${#input1}" - 1 )) ; for each in $( seq 0 ${count} ) ; do output0+=("${input0:${each}:1}") ; done 
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
                echo "GET_HOST function failed to launch." ; 
                pause ; 
                exit ; 
        fi ; 
fi 


###################################################################################################################################################
#   Check to see if a Windows OS partition is connected to keep it from the drives found in the search. 
#   Searches with fdisk first for 'Microsoft reserved' type partition to find the drive with the OS; 
#   they are on the same physical drive and the reserved partition is always before the OS.
#   Looks to see if the drive is mounted, if it is, unmounts.
#   Comment out below if you do not want the windows drive unmounted or change to 1
unmount=0
unset FIND_WIN_OS RECOV_PARTITION DRIVE_OS_COMPARE 
if RECOV_PARTITION=$(sudo fdisk -l | grep "Microsoft reserved" | awk '{print $1}') ; 
    then #   Moves right past first five charcters from the output ("/dev/") echoing only the next 3 characters (sd?, nvm, dis...) 
    DRIVE_OS_COMPARE="${RECOV_PARTITION:5:3}" 
    if eval sudo fdisk -l | grep "${DRIVE_OS_COMPARE}" | grep "Microsoft basic data" | awk '{print $1}' &>/dev/null 
        then  #   Using the infomation from above leads us to the ntemp_drive_fsys partition of the drive containing the Windows OS. 
        FIND_WIN_OS="$(sudo fdisk -l | grep "${DRIVE_OS_COMPARE}" | grep "Microsoft basic data" | grep -v '/media' | awk '{print $1}')" &>/dev/null 
        if findmnt "${FIND_WIN_OS}" &>/dev/null 2>&1
            then if [[ "${unmount}" -eq 0 ]] 
                then sudo umount -f "${FIND_WIN_OS}" &>/dev/null 2>&1
                else FIND_WIN_OS=':' ;
            fi 
            else FIND_WIN_OS=':' ;
        fi
    fi 
    else FIND_WIN_OS=':' ;
fi


declare THIS_FILESYSTEMS READABLE_TOTAL READABLE_IUSED READABLE_AVAIL THIS_DRIVE_PATHS # THIS_DRIVE_PCENT 
unset THIS_FILESYSTEMS READABLE_TOTAL READABLE_IUSED READABLE_AVAIL THIS_DRIVE_PATHS # THIS_DRIVE_PCENT 
### Filesystem information for selected host drive
THIS_FILESYSTEMS=$(df | grep -v "${FIND_WIN_OS}" | grep "${DRIVE_NAME}" | awk '{ print $1 }') ;
### Total storage space on the host drive
READABLE_TOTAL="$( echo $(( $(df | grep -v "${FIND_WIN_OS}" | grep "${DRIVE_NAME}" | awk '{ print $2 }' | sed "s/[^0-9]*//g" ) * 1000  )) | numfmt --to=si --suffix="b" "$@")" ;
### Total drive spaced used
READABLE_IUSED="$( echo $(( $(df | grep -v "${FIND_WIN_OS}" | grep "${DRIVE_NAME}" | awk '{ print $3 }' | sed "s/[^0-9]*//g" ) * 1000  )) | numfmt --to=si --suffix="b" "$@")" ;
### Total drive space used
READABLE_AVAIL="$( echo $(( $(df | grep -v "${FIND_WIN_OS}" | grep "${DRIVE_NAME}" | awk '{ print $4 }' | sed "s/[^0-9]*//g" ) * 1000  )) | numfmt --to=si --suffix="b" "$@")" ;
### Pathway to the selected host drive
THIS_DRIVE_PATHS=$(df | grep -v "${FIND_WIN_OS}" | grep "${DRIVE_NAME}" | awk '{ print $6 }')

mapfile -t FOUND_DRIVES_TOTAL < <( df | grep -v "${FIND_WIN_OS}" | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $2 }' ) ;  

###################################################################################################################################################
#   ----------------------------------------------------------- START DRIVE ARRAY VALUES ---------------------------------------------------------- 
#   START COLLECTION OF ARRAY DATA FOR ALL ATTACHED MEDIA DRIVES 
#   Load all the filesystems into the variable ALL_DRIVE_FSYST then compare to see if the destination drive is large enough to handle a one to one backup. 
declare -a TEMP_AFS TEMP_ADT TEMP_ADI TEMP_ADA  TEMP_ADP ; # TEMP_PCT 
declare -a ALL_DRIVE_FSYST ALL_DRIVE_TOTAL ALL_DRIVE_IUSED ALL_DRIVE_AVAIL ALL_DRIVE_PATHS ALL_DRIVES_PATHNAMES ; # ALL_DRIVE_PCENT
declare -a READABLE_ALL_TOTAL READABLE_ALL_IUSED READABLE_ALL_AVAIL ; 

unset TEMP_AFS TEMP_ADT TEMP_ADI TEMP_ADA  TEMP_ADP ; # TEMP_PCT 
unset ALL_DRIVE_FSYST ALL_DRIVE_TOTAL ALL_DRIVE_IUSED ALL_DRIVE_AVAIL ALL_DRIVE_PATHS ALL_DRIVES_PATHNAMES ; # ALL_DRIVE_PCENT
unset READABLE_ALL_TOTAL READABLE_ALL_IUSED READABLE_ALL_AVAIL ; 

mapfile -t TEMP_AFS < <( df | grep -v "${FIND_WIN_OS}" | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $1 }' ; ) ; 
mapfile -t TEMP_ADT < <( df | grep -v "${FIND_WIN_OS}" | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $2 }' ; ) ; 
mapfile -t TEMP_ADI < <( df | grep -v "${FIND_WIN_OS}" | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $3 }' ; ) ; 
mapfile -t TEMP_ADA < <( df | grep -v "${FIND_WIN_OS}" | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $4 }' ; ) ;
# mapfile -t TEMP_PCT < <( df | grep -v "${FIND_WIN_OS}" | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $5 }' ; ) ;
mapfile -t TEMP_ADP < <( df | grep -v "${FIND_WIN_OS}" | grep -v "${THIS_DRIVE_PATHS}" | grep 'media' | sort -k1 | awk '{ print $6 }' ; ) ;

for i in "${!FOUND_DRIVES_TOTAL[@]}" ; do
    if [[ ${THIS_DRIVE_IUSED} -lt "${FOUND_DRIVES_TOTAL[i]}" ]] ; then 
        ALL_DRIVE_FSYST+=("${TEMP_AFS[i]}"); 
        ALL_DRIVE_TOTAL+=("${TEMP_ADT[i]//[^0-9]*//}"); 
        ALL_DRIVE_IUSED+=("${TEMP_ADI[i]//[^0-9]*//}"); 
        ALL_DRIVE_AVAIL+=("${TEMP_ADA[i]//[^0-9]*//}"); 
        # ALL_DRIVE_PCENT+=("${TEMP_PCT[i]}"); 
        ALL_DRIVE_PATHS+=("${TEMP_ADP[i]}"); 
        READABLE_ALL_TOTAL+=("$( echo $(( ALL_DRIVE_TOTAL[i] * 1000  )) | numfmt --to=si --suffix="b" "$@")") ; 
        READABLE_ALL_IUSED+=("$( echo $(( ALL_DRIVE_IUSED[i] * 1000  )) | numfmt --to=si --suffix="b" "$@")") ; 
        READABLE_ALL_AVAIL+=("$( echo $(( ALL_DRIVE_AVAIL[i] * 1000  )) | numfmt --to=si --suffix="b" "$@")") ; 
    fi ; 
done ;

mapfile -t ALL_DRIVES_PATHNAMES < <(  for i in "${!ALL_DRIVE_PATHS[@]}" ; do basename "${ALL_DRIVE_PATHS[i]}" | sed 's/\(.\{12\}\).*/\1.../' ; done ) ;

#   ----------------------------------------------------------- END drive ARRAY VALUES ------------------------------------------------------------ 
###################################################################################################################################################

###################################################################################################################################################
#   Count the number of files found
declare -i COUNT_FILES;        
COUNT_FILES="${#ALL_DRIVE_FSYST[@]}"  
#   Count all the entries for each column
AFS_COUNT=${#ALL_DRIVE_FSYST} 
#ADT_COUNT=${#ALL_DRIVE_TOTAL} 
#ADI_COUNT=${#ALL_DRIVE_IUSED} 
#ADA_COUNT=${#ALL_DRIVE_AVAIL} 
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
    for EACH_DRIVE in "${!ALL_DRIVE_FSYST[@]}"; do 
        printf "%-${#UNDER_ADP}s\t%-${#UNDER_FST}s\t%-${#UNDER_ADT}s\t%-${#UNDER_ADI}s\t%-${#UNDER_ADA}s\n" \
        "${ALL_DRIVES_PATHNAMES[EACH_DRIVE]}" "${ALL_DRIVE_FSYST[EACH_DRIVE]}" "${READABLE_ALL_TOTAL[EACH_DRIVE]}" "${READABLE_ALL_IUSED[EACH_DRIVE]}" "${READABLE_ALL_AVAIL[EACH_DRIVE]}" ; 
    done ) 
    if [[ ${ALL_DRIVE_FSYST[0]} == "" ]] ; then AVAIL_DRIVES[0]="No qualified drives found..." ; HIDE_SELECTION=true ; fi

#   Put everything together and run the program 
while true ; do 
#   Start loop to configure, print out menu and run rsync program 
    clear 
    echo -e "\a\n\n\r" 
    #   List information for the host drive selected
    echo -e "  \tCurrent Drive: $(basename "${DRIVE_NAME}") \e[2;37m(${THIS_FILESYSTEMS})\e[0m   Total: \e[2;37m${READABLE_TOTAL}\e[0m Used: \e[2;37m${READABLE_IUSED}\e[0m Avail: \e[2:37m${READABLE_AVAIL}\e[0m\r\n" 

    #   Print the heading with titles and underline each column heading 
    printf "\t\e[2;4;22m%-${#UNDER_ADP}s\e[0m\t\e[4;22m%-${#UNDER_FST}s\e[0m\t\e[4;22m%-${#UNDER_ADT}s\e[0m\t\e[4;22m%-${#UNDER_ADI}s\e[0m\t\e[4;22m%-${#UNDER_ADA}s\e[0m\n" "Drive name" "Location" "Total " "Used " "Available " 
    
    #   Combine data gathered of available drives and list them in this format (size is listed in Mb, Gb, Tb...):
    # Add number 
    #   1)  <DriveName>            	/dev/sd??    	    <total>     	    <used>     	    <avail>
    for i in $(seq 1 "${#AVAIL_DRIVES[@]}"); do 
        printf '\t\e[1;97m%s\e[0m) ' "${i}" ; printf ' %s\n' "${AVAIL_DRIVES[$((i-1))]}"
    done 

    echo -en '\n\a' ; # Inset a space and toggle bell for notification

    # List options available other than entering the number from drive listing
    if [[ ! ${HIDE_SELECTION} ]] ; then echo -en "\t\e[0;97m" ; echo -n "A" ; echo -ne "\e[0m)  Backup to \e[1;97m\e[4;37mA\e[0mll drives above.\r\n" ; fi
    if [[ ! ${HIDE_SELECTION} ]] ; then echo -en "\t\e[0;97m" ; echo -n "S" ; echo -ne "\e[0m)  Select Directory to back up to a \e[1;97m\e[4;37mS\e[0mingle drive\r\n" ; fi
    if [[ ! ${HIDE_SELECTION} ]] ; then echo -en "\t\e[0;97m" ; echo -n "D" ; echo -ne "\e[0m)  Select \e[1;97m\e[4;37mD\e[0mirectory to back up to all drives.\r\n" ; fi
    echo -en "\t\e[0;97m" ; echo -n "F" ; echo -ne "\e[0m)  Select Directory or \e[1;97m\e[4;37mF\e[0mile to back up into any other Directory.\r\n\n" 
    echo -en "\t\e[0;97m" ; echo -n "Q" ; echo -ne "\e[0m)  \e[1;97m\e[4;37mQ\e[0muit script\r\n\n" 
    # Instructions
    echo -en "\tIf more than one selection is entered, the script will run in the sequece provided\n\r\n" 
    if [[ ! ${HIDE_SELECTION} ]] ; then echo -en "\t['A' = numbers will be ignored] \n" ; fi
    echo -en "\tSelection options: " ; echo -e "$( if [[ ! ${HIDE_SELECTION} ]] ; then echo "${NUM_SEQUENCE}, A, S, D, " ; fi )F or Q \n" 
    echo -en "\tEnter any option from the list above: " 
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
                zenity --notification --text="Attempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVE_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" 
                #   Place a title on the terminal top 
                echo -e " \033]0;Syncing from ${DRIVE_NAME} to ${ALL_DRIVE_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}\007" 
                #  Start the rsync program 
                RUN_RSYNC_PROG "${DRIVE_NAME}" "${ALL_DRIVE_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]}" ; EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" 
                #   Announce error 
                zenity --notification --text "rsync from ${DRIVE_NAME} to ${ALL_DRIVE_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" 
                #   Echo status to log 
                echo "$(date +%m-%d-%Y_%H%M) --> rsync to ${ALL_DRIVE_PATHS[ $(( OPT_ARRAY[eachDrive] - 1 )) ]} exit status: Code: ${EXIT_CODE} - ${REASON}" |& tee -a "${RSYNC_LOG}" &>/dev/null 
            ;;  #   end case selection 
            
            "A"|"a" ) 
                for a in "${!ALL_DRIVE_PATHS[@]}" ; do  
                    zenity --notification --text "Attempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVE_PATHS[a]}" 
                    #   Place a title on the terminal top 
                    echo -e " \033]0;Syncing from ${DRIVE_NAME} to ${ALL_DRIVE_PATHS[a]}\007" 
                    #  Start the rsync program 
                    RUN_RSYNC_PROG "${DRIVE_NAME}" "${ALL_DRIVE_PATHS[a]}" ; EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" 
                    #   Announce error 
                    zenity --notification --text "rsync from ${DRIVE_NAME} to ${ALL_DRIVE_PATHS[a]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" 
                    #   Echo status to log 
                    echo "$(date +%m-%d-%Y_%H%M) --> rsync to ${ALL_DRIVE_PATHS[a]} exit status: Code: ${EXIT_CODE} - ${REASON}" |& tee -a "${RSYNC_LOG}" &>/dev/null 
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
                        echo -en " \tOnly one drive detected.\n\r\tDo you wish to copy this folder to ${ALL_DRIVE_PATHS[0]}. Y/N? "; 
                        read -r yn 
                        case ${yn} in 
                            "Y"|"y" ) echo -e " \r\nThank you. Continuing..." 
                                zenity --notification --text " \t Attempting to run rsync.\r\n Attempting to run rsync from ${SINGLE_ALL_HOST} to ${ALL_DRIVE_PATHS[0]}" 
                                #  Start the rsync program 
                                RUN_RSYNC_PROG "${SINGLE_ALL_HOST}" "${ALL_DRIVE_PATHS[0]}" ; EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" 
                                zenity --notification --text "rsync from ${DRIVE_NAME} to ${ALL_DRIVE_PATHS[0]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" 
                            ;; #   end case selection 
                            "N"|"n" ) echo OK. Exiting... ; pause ; exit 
                            ;; #   end case selection 
                            *) echo "Selection invalid! Try again." ; pause 
                            ;; #   end case
                        esac 
                    done 
                        echo -e "$(date +%m-%d-%Y_%H%M) --> rsync to ${DRIVE_SEL}, exit status: Code: ${EXIT_CODE} - ${REASON}" |& tee -a "${RSYNC_LOG}" &>/dev/null 
                fi  
           ;; #   end case selection 

            "D"|"d" ) 
                unset SINGLE_DIR_HOST 
                SINGLE_DIR_HOST=$(zenity --file-selection --title="Select a directory for syncing to ${ALL_DRIVE_PATHS[d]}" --directory --filename="${MEDIA_PATH}/${PRIME_SUDOER}") &> /dev/null 
                for d in "${!ALL_DRIVE_PATHS}"; do  
                    zenity --notification --text "Attempting to run rsync from ${DRIVE_NAME} to ${ALL_DRIVE_PATHS[d]}/" 
                    echo -ne " \033]0;syncing from ${DRIVE_NAME} to ${ALL_DRIVE_PATHS[d]}/\007" 
                    #  Start the little dancing cursor 
                    RUN_RSYNC_PROG "${SINGLE_ALL_HOST}" "${ALL_DRIVE_PATHS[d]}" ; EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" 

                    #if ! TAB_OVER rsync "${RSYNC_FLAGS[@]}" -- "${SINGLE_ALL_HOST}/" "${ALL_DRIVE_PATHS[i]}" 2>&1 ; then EXIT_CODE=$? ; REASON="$(TRANSLATE_ERRORCODE "${EXIT_CODE}")" ; fi 
                    zenity --notification --text "rsync from ${SINGLE_DIR_HOST} to ${ALL_DRIVE_PATHS[d]} exit status:\nCode: ${EXIT_CODE} - ${REASON}" ;                        
                    echo -e "$(date +%m-%d-%Y_%H%M) --> rsync to ${ALL_DRIVE_PATHS[d]} exit status: Code: ${EXIT_CODE} - ${REASON}" |& tee -a "${RSYNC_LOG}" &>/dev/null 
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
                echo -e "$(date +%m-%d-%Y_%H%M) --> rsync ${SINGLE_HOST} to ${NEW_MOUNT_PATH} exit status: Code: ${EXIT_CODE} - ${REASON}" |& tee -a "${RSYNC_LOG}" &>/dev/null  
            ;; #   end case selection 

            "Q"|"q" ) exit 
            ;; #   end case selection 

            * ) 
                printf '\t%s' "Invalid selection. Please try again. " ; 
                printf '\t%s\r\n' "$(read -srn1 -p 'Press any key to continue...')" 
            ;; #   end case selection 

        #   end case
        esac 
    #   End loop to process each menu option
    done 

#   End loop to configure, print out selection menu and run rsync program 
done
