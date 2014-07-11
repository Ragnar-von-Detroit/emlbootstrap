#!/bin/bash
  #Check for highest UniqueID and for Staff GroupID for Standard Users.
  declare -ir lastid=$(/usr/bin/dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -1)
  #Staff GroupID is almost certainly 20 but why guess?
  declare -ir staffgid=$(/usr/bin/dscl . -read /Groups/staff PrimaryGroupID | cut -d " " -f 2)
  #Array of EML default users (besides EML Admin)
  declare -ar defusers=("student" "filmtech" "instructor")
  #DON'T escape spaces in paths for dscl!
  #Admin picture is Whiterose.tif, student is Golf.tif, Filmtech is Medal.tif, Instructor is Red Rose.tif
  declare -ar userpictures=("/Library/User Pictures/Sports/Golf.tif" "/Library/User Pictures/Fun/Medal.tif" "/Library/User Pictures/Flowers/Red Rose.tif")

  #createuser wants $1 USERNAME, $2 UNIQUEID, $3 USERPICTURE
  # create_user() {
  #   local userpath=/Users/"$1"
  #   #Convert first letter of username to Uppercase. This is just for Real Name key, which is what shows up on login screen. (eg. Instructor)
  #   local realnameupper=$(echo "$1" | /usr/bin/perl -pe 's/\S+/\u$&/g')
  #   sudo /usr/bin/dscl . -create "$userpath"
  #   sudo /usr/bin/dscl . -create "$userpath" UserShell /bin/bash
  #   sudo /usr/bin/dscl . -create "$userpath" RealName "$realnameupper"
  #   sudo /usr/bin/dscl . -create "$userpath" UniqueID "$2"
  #   sudo /usr/bin/dscl . -create "$userpath" PrimaryGroupID "$staffgid"
  #   sudo /usr/bin/dscl . -create "$userpath" NFSHomeDirectory "$userpath"
  #   sudo /usr/bin/dscl . -create "$userpath" hint "Ask EML Technician"
  #   sudo /usr/bin/dscl . -create "$userpath" Picture "$3"
  #   sudo passwd "$1"
  #   sudo mkdir "$userpath"
  #   printf "%s\n" "Creating ~/ at "\"$userpath\"" with the following items:"
  #   sudo cp -Rv /System/Library/User\ Template/English.lproj/ "$userpath"
  #   sudo chown -R "$1":staff "$userpath"
  #   printf "%s\n\n" "Finished creating account "\"$1\"" at "\"$userpath\""."
  # }

  # #Turn off icloud set up on first login. We don't want to have to personally log into each machine to go through the intro...
  # disable_icloud_setup() {
  #   local user="$1"
  #   local userpath=/Users/"$user"
  #   #defaults write will make this file properly for us. No reason to check if it exists.
  #   sudo defaults write "$userpath"/Library/Preferences/com.apple.SetupAssistant DidSeeCloudSetup -bool TRUE
  #   sudo defaults write "$userpath"/Library/Preferences/com.apple.SetupAssistant GestureMovieSeen none
  #   sudo defaults write "$userpath"/Library/Preferences/com.apple.SetupAssistant LastSeenCloudProductVersion "${sw_vers}"
  #   sudo chown "$user" "$userpath"/Library/Preferences/com.apple.SetupAssistant.plist
  # }

  configure_dock_per_user() {
    echo "Configuring dock for user "$1""
    local user="$1"
    local userpath=/Users/"$user"
    echo "default writing to "$userpath"/Library/Preferences..."
    #sudo cp -v /System/Library/CoreServices/Dock.app/Contents/Resources/en.lproj/default.plist "$userpath"/Library/Preferences/com.apple.dock.plist
    sudo defaults delete "$userpath"/Library/Preferences/com.apple.dock persistent-apps*
    sudo defaults delete "$userpath"/Library/Preferences/com.apple.dock persistent-others*
    sudo defaults write "$userpath"/Library/Preferences/com.apple.dock use-new-list-stack -bool YES
    sudo defaults write "$userpath"/Library/Preferences/com.apple.dock mouse-over-hilite-stack -bool true
    #recent applications stack
    sudo defaults write "$userpath"/Library/Preferences/com.apple.dock persistent-others -array-add '{ "tile-data" = { "list-type" = 1; }; "tile-type" = "recents-tile"; }'
    #recent documents stack
    sudo defaults write "$userpath"/Library/Preferences/com.apple.dock persistent-others -array-add '{ "tile-data" = { "list-type" = 2; }; "tile-type" = "recents-tile"; }'
    sudo chown "$user" "$userpath"/Library/Preferences/com.apple.dock
  }

  # configure_screensaver_per_user() {
  #
  #
  # }

main() {
  for i in "${!defusers[@]}"
  do
    local index="$i"
    local uniqueid="$((lastid + index + 1))" #+1 to not overwrite the LASTID on the 0 index of the array.
    local username="${defusers[$i]}"
    local userpicture="${userpictures[$i]}"
    #Don't create Student and Instructor accounts if they already exist. Warning! We only check for
    #Users in standard OSX location /Users/!
    if [[ ! $(/usr/bin/dscl . list /Users | grep -ci "$username") -eq 0 ]]; then
      printf "\n%s\n" "User "\"$username\"" does not currently exist. making "\"$username\"" account now!"
      # create_user "$username" "$uniqueid" "$userpicture"
      # disable_icloud_setup "$username"
      configure_dock_per_user "$username"
      else
      printf "%s\n\n" "User "\"$username\"" already exists. Cannot, should not, and will not overwrite. Skipping!"
    fi
  done
}

main
