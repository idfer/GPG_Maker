#! /bin/bash
#shopt -s -o nounset
readonly PROGNAME=$(basename $0)
#readonly PROGDIR=$(readlink -m $(dirname $0))
readonly ARG="$@"
readonly GPGKEY_PATH=~/.gnu
readonly KEY_TEMP=${TMP:-/tmp}
readonly DIALOG_HEIGHT=16
readonly DIALOG_WIDTH=51
readonly DIALOG_MENU_HEIGHT=4
readonly DIALOG_FORM_HEIGHT=3


mainMenu() {
    OPTION=$(dialog --title "Main Menu" --menu "\nChoose one" $DIALOG_HEIGHT $DIALOG_WIDTH $DIALOG_MENU_HEIGHT \
    0 "Set Up GPG Key" 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus -eq 0 ]; then
        dialog --title "Set Up GPG Key" --yesno "\nDo you want to setup GPG Key?" $DIALOG_HEIGHT $DIALOG_WIDTH
        if [ $? -eq 0 ]; then
            setGPGKeyAlgorithm
        fi
        mainMenu
    fi
    exit $exitstatus;
}


setGPGKeyAlgorithm() {

        KEY=$(dialog --title "Set Up GPG Key" --menu "\nSelect Key Algorithm" $DIALOG_HEIGHT $DIALOG_WIDTH $DIALOG_MENU_HEIGHT \
        1 "RSA and RSA (default)" \
        2 "DSA and Elgamal" \
        3 "DSA (sign only)" \
        4 "RSA (sign only)" 3>&1 1>&2 2>&3)

        exitstatus=$?
        if [ $exitstatus -eq 0 ]; then
            case $KEY in
                "1")
                    KEY_TYPE="RSA"
                    SUBKEY_TYPE="RSA"
                    ;;
                "2")
                    KEY_TYPE="DSA"
                    SUBKEY_TYPE="ELG-E"
                    ;;
                "3")
                    KEY_TYPE="DSA"
                    KEY_USAGE="sign"
                    ;;
                "4")
                    KEY_TYPE="RSA"
                    KEY_USAGE="sign"
                    ;;
            esac
            KEY_LENGTH=$(dialog --title "Set Up GPG Key" --inputbox "\n$KEY_TYPE Keys may be between 1024 and 4096 bits long.\nWhat keysize do you want? (2048)" \
                       $DIALOG_HEIGHT $DIALOG_WIDTH "2048" 3>&1 1>&2 2>&3)

            if [ $? -eq 0 ]; then
                if [ $(($KEY_LENGTH%64)) -ne 0 ]; then

                    dialog --title "Set Up GPG Key" --msgbox "\nRequested keysize is $KEY_LENGTH bits\nrounded up to $((($KEY_LENGTH/64+1)*64)) bits" $DIALOG_HEIGHT $DIALOG_WIDTH
                    KEY_LENGTH=$((($KEY_LENGTH/64+1)*64))
                fi
                setGPGKeyExpiration
            fi
        fi
        mainMenu
}
setGPGKeyExpiration() {
    local timestamp

    # Step 2 - key expiration date
    KEY_EXPIRE=$(dialog --title "Set Up GPG Key" --inputbox "\nPlease specify how long the key should be valid. \n
    0 = key does not expire \n
    <n> = key expires in n days \n
    <n>w = key expires in n weeks \n
    <n>m = key expires in n months \n
    <n>y = key expires in n years \n" $DIALOG_HEIGHT $DIALOG_WIDTH "0" 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus -eq 0 ]; then

        if [[ $KEY_EXPIRE =~ ^([0-9]{1,2}[wmy]{0,1})$ ]]; then

            if [[ $KEY_EXPIRE =~ ^0{1,2}[wmy]{0,1}$ ]]; then
                dialog --title "Set Up GPG Key" --yesno "\nKey does not expire at all\n Is this correct?" $DIALOG_HEIGHT $DIALOG_WIDTH
            else
                dateformat=$(echo $KEY_EXPIRE | sed 's/w/week/g' | sed 's/m/month/g' | sed 's/y/year/g' )
                timestamp=$(date --date=$dateformat +"%c %Z")
                dialog --title "Set Up GPG Key" --yesno "\nKey expires at $timestamp\n Is this correct?" $DIALOG_HEIGHT $DIALOG_WIDTH
            fi
            if [ $? -eq 0 ]; then
                setGPGUserIdentification
            else
                setGPGKeyExpiration
            fi
        else
            dialog --title "Warnning" --infobox "Invalid Value!" 3 34
            sleep 1
            setGPGKeyExpiration
        fi

    else
        setGPGKeyAlgorithm
    fi

}
setGPGUserIdentification() {
    local i

    #IFS=$'\n'
    #read -r -d '' REAL_NAME EMAIL COMMENT < <
    INPUT=$(dialog --no-nl-expand --title "Set Up GPG Key" --form "GnuPG needs to construct a user ID to identify your key. " $DIALOG_HEIGHT $DIALOG_WIDTH $DIALOG_FORM_HEIGHT \
    "Real name"     1 1 "" 1 15 30 0 \
    "Email address" 2 1 "" 2 15 30 0 \
    "Comment"       3 1 "" 3 15 30 0 \
    3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        setGPGKeyExpiration
    else

        IFS=$'\n'
        read -r -d '' REAL_NAME EMAIL COMMENT << EOF
$INPUT
EOF

        if [ -z $REAL_NAME ] || [ -z $EMAIL ]; then
            dialog --title "Set UP GPG KEY" --infobox "Real name and Email can't be empty!" 3 40
            sleep 1
            setGPGUserIdentification
        fi

        makeGPGKey
    fi
}

makeGPGKey() {


    dialog --title "Set Up GPG Key" --yesno "Follow GPG info was correct?\n \
    Key-Type: $KEY_TYPE\n \
    Key-Type: $KEY_TYPE\n \
    Key-Length: $KEY_LENGTH\n \
    Subkey-Type: $SUBKEY_TYPE\n \
    Subkey-Length: $KEY_LENGTH\n \
    Name-Real: $REAL_NAME\n \
    Name-Comment: $COMMENT\n \
    Name-Email: $EMAIL\n \
    Expire-Date: $KEY_EXPIRE\n \
    %pubring foo.pub\n \
    %secring foo.sec\n " $DIALOG_HEIGHT $DIALOG_WIDTH

    if [[ $? -eq 0 ]]; then

    dialog --title "Set Up GPG Key" --infobox "\nGenerating a basic OpenPGP Key!\nPlease wait..." 6 40

    gpg2 --batch --gen-key << EOF
    Key-Type: $KEY_TYPE
    Key-Length: $KEY_LENGTH
    Subkey-Type: $SUBKEY_TYPE
    Subkey-Length: $KEY_LENGTH
    Name-Real: $REAL_NAME
    Name-Comment: $COMMENT
    Name-Email: $EMAIL
    Expire-Date: $KEY_EXPIRE
    %pubring foo.pub
    %secring foo.sec
    %commit
EOF
    dialog --title "Set Up GPG Key" --infox "\nImport key..." 5 40

    gpg2 --import-key $KEY_TEMP/foo.pub
    gpg2 --import-key $KEY_TEMP/foo.sec

    dialog --title "Set Up GPG Key" --msgbox "Success!" $DIALOG_HEIGHT $DIALOG_WIDTH
    else
        setGPGUserIdentification
    fi
}

mainMenu
