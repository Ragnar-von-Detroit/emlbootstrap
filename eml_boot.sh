#!/bin/bash

intro() {
  cat <<- EOF
  EML BOOTSTRAP INTRO
  ===================
  This is the new install script for the English Media Lab.
  It will do the following tasks for you:

  1. Install xcode command line tools needed for Homebrew & Cask
  2. Install and set up Homebrew and Caskroom
  3. Set up PubkeyAuthentication in sshd_config and install SSH public key.
  4. Create Student, FilmTech, and Instructor as Standard Users. Be sure to have the standard passwords ready.
  5. Change Dock settings for all users to make it pretty the way we like it.

  This script needs to be run as EML Admin. It will provision the computer for you so that it is ready for Ansible management
  from the EML Tech machine.
EOF
}

install_xcode(){
  #this whole thing from osxc & https://github.com/timsutton/osx-vm-templates/blob/master/scripts/xcode-cli-tools.sh
  declare -xr osx_vers=$(sw_vers -productVersion | awk -F "." '{print $2}')

  dev_tools(){
    if [ "$osx_vers" -ge 9 ]; then
      # create the placeholder file that's checked by the CLI updates .dist in Apple's SUS catalog
      /usr/bin/touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
      # find the product id with "Developer" in the name
      prodid=$(/usr/sbin/softwareupdate -l | awk '/Developer/{print x};{x=$0}' | awk '{print $2}')
      # install it (amazingly, it won't find the update if we put the update ID in double-quotes)
      /usr/sbin/softwareupdate -i $prodid -v
      # on 10.7/10.8, we'd instead download from public download URLs, which can be found in
      # the dvtdownloadableindex:
      # https://devimages.apple.com.edgekey.net/downloads/xcode/simulators/index-3905972D-B609-49CE-8D06-51ADC78E07BC.dvtdownloadableindex
    else
      [ "$osx_vers" -eq 7 ] && dmgurl=http://devimages.apple.com/downloads/xcode/command_line_tools_for_xcode_os_x_lion_april_2013.dmg
      [ "$osx_vers" -eq 8 ] && dmgurl=http://devimages.apple.com/downloads/xcode/command_line_tools_for_osx_mountain_lion_april_2014.dmg
      toolspath="/tmp/clitools.dmg"
      /usr/bin/curl "$dmgurl" -o "$toolspath"
      tmpmount=`/usr/bin/mktemp -d /tmp/clitools.xxxx`
      /usr/bin/hdiutil attach "$toolspath" -mountpoint "$tmpmount"
      /usr/sbin/installer -pkg "$(find $tmpmount -name '*.mpkg')" -target /
      /usr/bin/hdiutil detach "$tmpmount"
      /bin/rm -rf "$tmpmount"
      /bin/rm "$toolspath"
    fi
  }

  # build array of most probable receipts from cli tools for current & past os versions, partially from
  # https://github.com/homebrew/homebrew/blob/208f963cf2/library/homebrew/os/mac/xcode.rb#l147-l150
  declare -ra bundle_ids=('com.apple.pkg.DeveloperToolsCLI' \
  'com.apple.pkg.DeveloperToolsCLILeo' 'com.apple.pkg.CLTools_Executables' \
  'com.apple.pkg.XcodeMAS_iOSSDK_7_0')
  # set flag for the presence of a cli tools receipt
  declare -i xcode_cli=0
  # iterate over array, break out and skip install if we get a zero return code
  for id in ${bundle_ids[@]}; do
    /usr/sbin/pkgutil --pkg-info=$id > /dev/null 2>&1
    if [[ $? == 0 ]]; then
      echo "Found "$id", xcode developer cli tools install not needed"
      echo ""
      echo ""
      ((xcode_cli++))
      break
    fi
  done

  if [[ $xcode_cli -ne 1 ]]; then
    echo "xcode tools installation"
    echo "------------------------"
    echo ""
    echo "please wait while xcode is installed"
    dev_tools
    if [[ $? -ne 0 ]]; then
      echo "xcode installation failed" && exit 1
    fi
    echo ""
    echo ""
  fi
}

install_homebrew() {
  echo "Installing Homebrew. Follow the prompts."
  ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"
  echo "Fixing Brew path"
  echo "export PATH=/usr/local/bin:$PATH" >> ~/.bash_profile
}

install_cask() {
  echo "Installing Cask"
  brew install caskroom/cask/brew-cask
  #fix brew path and make sure Cask symlinks to /Applications rather than ~/Applications.
  #This way we can ensure the all gui programs are accessible for all users, including our standard accounts.
  echo "Changing default Cask symlink location to /Applications"
  echo "export HOMEBREW_CASK_OPTS="--appdir=/Applications"" >> ~/.bash_profile
}

configure_SSHD() {
  declare -r bakdate=$(date -j +%d.%m.%y)
  echo "Editing /etc/sshd_config: LogLevel, PermitRootLogin, PubkeyAuthentication, PasswordAuthentication. Need root permissions."
  sudo sed -i."$bakdate".bak \
  -e 's/^#LogLevel INFO/LogLevel INFO/' \
  -e 's/^#PermitRootLogin .*/PermitRootLogin no/' \
  -e 's/^#PubkeyAuthentication .*/PubkeyAuthentication yes/' \
  -e 's/^#PasswordAuthentication .*/PasswordAuthentication no/' \
  /etc/sshd_config
}

install_pubkey() {
  echo "Installing public key from Github to ~/.ssh/authorized_keys"
  mkdir ~/.ssh
  touch ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  ruby -e 'require "json"; require "open-uri"; JSON.parse(open("https://api.github.com/users/emltech/keys").read).each{|x|puts x["key"]}' >> ~/.ssh/authorized_keys
}

#clear the dock for all users BEFORE creating user accounts. Then apply defaults. We'll populate the dock with dockutil through Homebrew + Ansible
configure_dock() {
  sudo defaults write /System/Library/CoreServices/Dock.app/Contents/Resources/en.lproj/default.plist persistent-apps -array
  defaults write com.apple.dock use-new-list-stack -bool YES
  #recent applications stack
  defaults write com.apple.dock persistent-others -array-add '{ "tile-data" = { "list-type" = 1; }; "tile-type" = "recents-tile"; }'
  defaults write com.apple.dock mouse-over-hilite-stack -bool true
}

create_users() {
  #Check for highest UniqueID and for Staff GroupID for Standard Users.
  declare -ir lastid=$(/usr/bin/dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -1)
  #Staff GroupID is almost certainly 20 but why guess?
  declare -ir staffgid=$(/usr/bin/dscl . -read /Groups/staff PrimaryGroupID | cut -d " " -f 2)
  #Array of EML default users (besides EML Admin)
  declare -ar defusers=("student" "filmtech" "instructor")
  #Array of User Pictures. DON'T escape spaces in paths for dscl!
  #Admin picture is Whiterose.tif, student is Golf.tif, Filmtech is Medal.tif, Instructor is Red Rose.tif
  declare -ar userpictures=("/Library/User Pictures/Sports/Golf.tif" "/Library/User Pictures/Fun/Medal.tif" "/Library/User Pictures/Flowers/Red Rose.tif")

  #createuser wants $1 USERNAME, $2 UNIQUEID, $3 USERPICTURE
  create_user(){
    local userpath=/Users/"$1"
    #Conver first letter of username to Uppercase to seem more profesh (eg. Instructor) 
    local realnameupper=$(echo "$1" | /usr/bin/perl -pe 's/\S+/\u$&/g')
    sudo /usr/bin/dscl . -create "$userpath"
    sudo /usr/bin/dscl . -create "$userpath" UserShell /bin/bash
    sudo /usr/bin/dscl . -create "$userpath" RealName "$realnameupper"
    sudo /usr/bin/dscl . -create "$userpath" UniqueID "$2"
    sudo /usr/bin/dscl . -create "$userpath" PrimaryGroupID "$staffgid"
    sudo /usr/bin/dscl . -create "$userpath" NFSHomeDirectory "$userpath"
    sudo /usr/bin/dscl . -create "$userpath" hint "Ask EML Technician"
    sudo /usr/bin/dscl . -create "$userpath" Picture "$3"
    sudo passwd "$1"
    mkdir "$userpath"
    printf "%s\n" "Creating ~/ at "\"$userpath\"" with the following items:"
    sudo cp -Rv /System/Library/User\ Template/English.lproj "$userpath"
    sudo chown -R "$1":staff "$userpath"
    printf "%s\n\n" "Finished creating account "\"$1\"" at "\"$userpath\""."
  }

  for i in "${!defusers[@]}"
  do
    local index="$i"
    local uniqueid="$((lastid + index + 1))" #+1 to not overwrite the LASTID on the 0 index of the array.
    local username="${defusers[$i]}"
    local userpicture="${userpictures[$i]}"
    #Don't create Student and Instructor accounts if they already exist. Warning! We only check for
    #Users in standard OSX location /Users/!
    if [[ $(/usr/bin/dscl . list /Users | grep -ci "$username") -eq 0 ]]; then
      printf "\n%s\n" "User "\"$username\"" does not currently exist. making "\"$username\"" account now!"
      create_user "$username" "$uniqueid" "$userpicture"
    else
      printf "%s\n\n" "User "\"$username\"" already exists. Cannot, should not, and will not overwrite. Skipping!"
    fi
  done
}

main() {
    #Before we start. Check if we have admin privileges
    declare -ir in_admin="$(/usr/bin/dscl /Search read /Groups/admin GroupMembership | /usr/bin/grep -c $USER)"
    [ "$in_admin" != 1 ] \
    && printf "%s\n" "This script requires admin access, you're logged in as $USER!" \
    && exit 1

  intro
  read -p "Continue? [Press Enter]"
  install_xcode
  install_homebrew
  install_cask
  configure_SSHD
  install_pubkey
  configure_dock
  create_users
}
main
