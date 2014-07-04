#!/bin/bash

intro() {
  cat <<- EOF
  EML BOOTSTRAP INTRO
  ===================
  This is the new install script for the English Media Lab.
  It will do the following tasks for you:

  1. Install xcode command line tools (needed for Homebrew & Cask)
  2. Install and set up Homebrew and Caskroom
  3. Set up PubkeyAuthentication in sshd_config and install SSH public key.
  4. Create Student, FilmTech, and Instructor as Standard Users. (Be sure to have the standard passwords ready)
  5. Change Dock settings for all users to make it pretty the way we like it.

  This script needs to be run as EML Admin. It will provision the computer for you so that it is ready for Ansible management
	from the EML Tech machine.

  EOF
}

install_xcode(){
  #this whole thing from osxc & https://github.com/timsutton/osx-vm-templates/blob/master/scripts/xcode-cli-tools.sh
  declare -xr OSX_VERS=$(sw_vers -productVersion | awk -F "." '{print $2}')

  dev_tools(){
    if [ "$OSX_VERS" -ge 9 ]; then
      # create the placeholder file that's checked by the CLI updates .dist in Apple's SUS catalog
      /usr/bin/touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
      # find the product id with "Developer" in the name
      PRODID=$(/usr/sbin/softwareupdate -l | awk '/Developer/{print x};{x=$0}' | awk '{print $2}')
      # install it (amazingly, it won't find the update if we put the update ID in double-quotes)
      /usr/sbin/softwareupdate -i $PRODID -v
      # on 10.7/10.8, we'd instead download from public download URLs, which can be found in
      # the dvtdownloadableindex:
      # https://devimages.apple.com.edgekey.net/downloads/xcode/simulators/index-3905972D-B609-49CE-8D06-51ADC78E07BC.dvtdownloadableindex
    else
      [ "$OSX_VERS" -eq 7 ] && DMGURL=http://devimages.apple.com/downloads/xcode/command_line_tools_for_xcode_os_x_lion_april_2013.dmg
      [ "$OSX_VERS" -eq 8 ] && DMGURL=http://devimages.apple.com/downloads/xcode/command_line_tools_for_osx_mountain_lion_april_2014.dmg
      TOOLSPATH="/tmp/clitools.dmg"
      /usr/bin/curl "$DMGURL" -o "$TOOLSPATH"
      TMPMOUNT=`/usr/bin/mktemp -d /tmp/clitools.XXXX`
      /usr/bin/hdiutil attach "$TOOLSPATH" -mountpoint "$TMPMOUNT"
      /usr/sbin/installer -pkg "$(find $TMPMOUNT -name '*.mpkg')" -target /
      /usr/bin/hdiutil detach "$TMPMOUNT"
      /bin/rm -rf "$TMPMOUNT"
      /bin/rm "$TOOLSPATH"
    fi
  }

  # Build array of most probable receipts from CLI tools for current & past OS versions, partially from
  # https://github.com/Homebrew/homebrew/blob/208f963cf2/Library/Homebrew/os/mac/xcode.rb#L147-L150
  declare -ra BUNDLE_IDS=('com.apple.pkg.DeveloperToolsCLI' \
  'com.apple.pkg.DeveloperToolsCLILeo' 'com.apple.pkg.CLTools_Executables' \
  'com.apple.pkg.XcodeMAS_iOSSDK_7_0')
  # Set flag for the presence of a CLI tools receipt
  declare -i XCODE_CLI=0
  # Iterate over array, break out and skip install if we get a zero return code
  for id in ${BUNDLE_IDS[@]}; do
    /usr/sbin/pkgutil --pkg-info=$id > /dev/null 2>&1
    if [[ $? == 0 ]]; then
      echo "Found "$id", Xcode Developer CLI Tools install not needed"
      echo ""
      echo ""
      ((XCODE_CLI++))
      break
    fi
  done

  if [[ $XCODE_CLI -ne 1 ]]; then
    echo "XCode Tools Installation"
    echo "------------------------"
    echo ""
    echo "Please wait while Xcode is installed"
    dev_tools
    if [[ $? -ne 0 ]]; then
      echo "Xcode installation failed" && exit 1
    fi
    echo ""
    echo ""
  fi
}

installHomebrew() {
  echo "Installing Homebrew. Follow the prompts."
  ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"
  echo "Fixing Brew path"
  echo "export PATH=/usr/local/bin:$PATH" >> ~/.bash_profile
}

installCask() {
  echo "Installing Cask"
  brew install caskroom/cask/brew-cask
  #fix brew path and make sure Cask symlinks to /Applications rather than ~/Applications.
  #This way we can ensure the all gui programs are accessible for all users.
  echo "Changing default Cask symlink location to /Applications"
  echo "export HOMEBREW_CASK_OPTS="--appdir=/Applications"" >> ~/.bash_profile
}

confSSHD() {
  declare -r BAKDATE=$(date -j +%d.%m.%y)
  echo "Editing /etc/sshd_config: LogLevel, PermitRootLogin, PubkeyAuthentication, PasswordAuthentication. Need root permissions."
  sudo sed -i."$BAKDATE".bak \
  -e 's/^#LogLevel INFO/LogLevel INFO/' \
  -e 's/^#PermitRootLogin .*/PermitRootLogin no/' \
  -e 's/^#PubkeyAuthentication .*/PubkeyAuthentication/' \
  -e 's/^#PasswordAuthentication .*/PasswordAuthentication no/' \
  /etc/sshd_config
}

installPubkey() {
  echo "Installing public key from Github to ~/.ssh/authorized_keys"
  mkdir ~/.ssh
  touch ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  ruby -e 'require "json"; require "open-uri"; JSON.parse(open("https://api.github.com/users/emltech/keys").read).each{|x|puts x["key"]}' >> ~/.ssh/authorized_keys
}

configDock() {
  #clear the dock for all users BEFORE creating user accounts. Then apply defaults. We'll populate the dock with dockutil through Homebrew + Ansible
  sudo defaults write /System/Library/CoreServices/Dock.app/Contents/Resources/en.lproj/default.plist persistent-apps -array
  defaults write com.apple.dock use-new-list-stack -bool YES
  #recent applications stack
  defaults write com.apple.dock persistent-others -array-add '{ "tile-data" = { "list-type" = 1; }; "tile-type" = "recents-tile"; }'
  defaults write com.apple.dock mouse-over-hilite-stack -bool true
}

createUsers() {
  #Check for highest UniqueID and for Staff GroupID for Standard Users.
  declare -ir LASTID=$(/usr/bin/dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -1)
  #Staff GroupID is almost certainly 20 but why guess?
  declare -ir STAFFGID=$(/usr/bin/dscl . -read /Groups/staff PrimaryGroupID | cut -d " " -f 2)
  #Array of EML default users (besides EML Admin)
  declare -ar DEFUSERS=("student" "filmtech" "instructor")
  #Array of User Pictures. DON'T escape spaces in paths for dscl!
  #Admin picture is Whiterose.tif, student is Golf.tif, Filmtech is Medal.tif, Instructor is Red Rose.tif
  declare -ar USERPICTURES=("/Library/User Pictures/Sports/Golf.tif" "/Library/User Pictures/Fun/Medal.tif" "/Library/User Pictures/Flowers/Red Rose.tif")

  #createUser wants $1 USERNAME, $2 UNIQUEID, $3 USERPICTURE
  createUser(){
    local USERPATH=/Users/"$1"
    /usr/bin/dscl . -create "$USERPATH"
    /usr/bin/dscl . -create "$USERPATH" UserShell /bin/bash
    /usr/bin/dscl . -create "$USERPATH" RealName "$1"
    /usr/bin/dscl . -create "$USERPATH" UniqueID "$2"
    /usr/bin/dscl . -create "$USERPATH" PrimaryGroupID "$STAFFGID"
    /usr/bin/dscl . -create "$USERPATH" NFSHomeDirectory "$USERPATH"
    /usr/bin/dscl . -create "$USERPATH" hint "Ask EML Technician"
    /usr/bin/dscl . -create "$USERPATH" Picture "$3"
    passwd "$1"
    mkdir "$USERPATH"
    printf "%s\n" "Creating ~/ at "\"$USERPATH\"" with the following items:"
    cp -Rv /System/Library/User\ Template/English.lproj "$USERPATH"
    chown -R "$1":staff "$USERPATH"
    printf "%s\n\n" "Finished creating account "\"$1\"" at "\"$USERPATH\""."
  }

  for i in "${!DEFUSERS[@]}"
  do
    local INDEX="$i"
    local UNIQUEID="$((LASTID + INDEX + 1))" #+1 to not overwrite the LASTID on the 0 index of the array.
    local USERNAME="${DEFUSERS[$i]}"
    local USERPICTURE="${USERPICTURES[$i]}"
    #Don't create Student and Instructor accounts if they already exist. Warning! We only check for
    #Users in standard OSX location /Users/!
    if [[ $(/usr/bin/dscl . list /Users | grep -ci "$USERNAME") -eq 0 ]]; then
      printf "%s\n\n" "User "\"$USERNAME\"" does not currently exist. Making "\"$USERNAME\"" account now!"
      createUser "$USERNAME" "$UNIQUEID" "$USERPICTURE"
    else
      printf "%s\n\n" "User "\"$USERNAME\"" already exists. Cannot, should not, and will not overwrite. Skipping!"
    fi
  done
}

main() {
	#Before we start. Check if we have admin privileges
	declare -ir IN_ADMIN="$(/usr/bin/dscl /Search read /Groups/admin GroupMembership | /usr/bin/grep -c $USER)"
	[ "$IN_ADMIN" != 1 ] \
	&& printf "%s\n" "This script requires admin access, you're logged in as $USER!" \
	&& exit 1

	intro
	read -p "Continue? [Press Enter]"
	installXcode
	installHomebrew
	installCask
	confSSHD
	installPubkey
	configDock
	createUsers
}

main
