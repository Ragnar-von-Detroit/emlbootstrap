#!/bin/bash

declare -xr osx_vers=$(sw_vers -productVersion | awk -F. '{print $2}')
declare -xr sw_vers=$(sw_vers -productVersion)

#OUTPUT STYLING
style_text() {
  RESTORE='\033[0m'

  RED='\033[00;31m'
  GREEN='\033[00;32m'
  YELLOW='\033[00;33m'
  CYAN='\033[00;36m'
  UNDY='\033[4m'
  BOLD='\033[1m'

  case "$1" in
    error)
      printf "\n${RED}${BOLD}%s\t" "$0"
      printf "${UNDY}%s${RESTORE}\n" "$2"
      ;;
    warn)
      printf "\n${YELLOW}${BOLD}%s\t" "$0"
      printf "${UNDY}%s${RESTORE}\n" "$2"
      ;;
    success)
      printf "\n${GREEN}${BOLD}%s\t" "$0"
      printf "${UNDY}%s${RESTORE}\n" "$2"
      ;;
    highlight)
      printf "\n${BOLD}%s${RESTORE}\n" "$2"
      ;;
    explain)
      printf "\n${CYAN}%s\t" "$0"
      printf "${UNDY}%s${RESTORE}\n\n" "$2"
      ;;
    *)
      echo "'print_status' error. You didn't give me a colour."
  esac
}

intro() {
read -r -d '' Printro <<EOF
EML BOOTSTRAP INTRO
================================================================================

This is the bootstrap script for the English Media Lab.

This script should be run on a fresh install only. We do check before
overwriting but don't trust us.

Here's what it does:
• Install and set up Homebrew and Homebrew Cask.
  This will trigger the install of Command Line Tools from Apple.
  You should allow this.
• Set up PubkeyAuthentication in sshd_config and install SSH public key.
• Create Student, FilmTech, and Instructor as Standard Users.
  Be sure to have the standard passwords ready.

This script needs to be run as EML Admin. It will make a basic minimum provision
of the computer for you so that it is ready for Ansible management
from the EML Tech machine.

You should reboot or log out and back in after this script is finished.
--------------------------------------------------------------------------------
EOF
style_text highlight "${Printro}"
}

#El capitan now includes /usr/local/bin in path so we no longer need to create
#user rc & profile dotfiles. Instead, just put the brew cask appdir var in
#/etc/bashrc

install_homebrew_and_cask() {
  local find_brew
  local brew_installed
  local cask_appdir="export HOMEBREW_CASK_OPTS=\"--appdir=/Applications\""

  type brew >/dev/null 2>&1
  brew_installed=$?

  style_text explain "Trying to install Homebrew."

  check_cask_options() {
    style_text explain "Making /Applications the app directory for brew cask"
    if grep -q "$cask_appdir" /etc/bashrc ; then
      style_text error "Cask options are already in /etc/bashrc. Skipping."
    else
      style_text explain "Changing default Cask symlink location to /Applications in /etc/bashrc"
      echo "$cask_appdir" | sudo tee -a /etc/bashrc
    fi
  }

  if [[ "$brew_installed" -eq 0 ]]; then
    style_text warn "Brew is alread installed. Skipping installation."
  else
    style_text explain "Installing Homebrew. Follow the prompts. Requires root. You'll be asked to install Command Line Tools. Allow it."
    /usr/bin/ruby -e "$(/usr/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi

  #Install cask. We used to check if cask had been installed but now simply
  #calling `brew cask` installs (taps) it. Instead just double check that brew
  #installed to avoid confusing output.
  type brew >/dev/null 2>&1
  brew_installed=$?
  if [[ "$brew_installed" -eq 0 ]]; then
    style_text explain "Installing Cask."
    brew cask
    check_cask_options
  else
    style_text error "Homebrew isn't installed. Something must have gone wrong."
  fi
}

system_setup() {
  declare -r bakdate=$(/bin/date -j +%d.%m.%y)
  declare -r publickey=$(curl -fSsl https://api.github.com/users/emltech/keys \
  | grep "key" \
  | cut -d " " -f 6,7 \
  | sed 's/"//g')

  style_text explain "Please type computer name [eg EML0011]"

  read compname

  sudo scutil --set ComputerName "$compname"
  sudo scutil --set LocalHostName "$compname"
  sudo scutil --set HostName "$compname"

  style_text explain "Setting up computer for Admin management..."

  #set power and sleep schedule, set autorestart after power failure, set wake on network/modem access
  style_text explain "Setting wake schedule. Admin password is required"
  sudo /usr/bin/pmset repeat wakeorpoweron MTWRF 08:59:00 shutdown MTWRFSU 22:00:00
  sudo /usr/bin/pmset displaysleep 120 disksleep 240 sleep 480 womp 1 autorestart 1 networkoversleep 1
  sudo /usr/sbin/systemsetup -setwakeonnetworkaccess on

  #sleep security
  /usr/bin/defaults write com.apple.screensaver askForPassword 1
  /usr/bin/defaults write com.apple.screensaver askForPasswordDelay -int 5

  #Turn on Remote Desktop control with full access for Admin account only.
  style_text explain "Setting up ARD access for $USER"
  sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate \
  -configure \
  -access -on \
  -users "$USER" \
  -privs -all \
  -restart -agent

  #ssh admin access
  style_text explain "Turning on SSH login in System Preferences."
  sudo /usr/sbin/systemsetup -setremotelogin On
  sudo /usr/sbin/systemsetup -getremotelogin
  #turn on firewall but allow ssh, ard, etc.
  sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1


  style_text explain "Editing /etc/sshd_config for better security."
  sudo sed -i."$bakdate".bak \
  -e 's/^#LogLevel INFO/LogLevel INFO/' \
  -e 's/^#PermitRootLogin .*/PermitRootLogin no/' \
  -e 's/^#PubkeyAuthentication .*/PubkeyAuthentication yes/' \
  -e 's/^#PasswordAuthentication .*/PasswordAuthentication no/' \
  /etc/ssh/sshd_config
  style_text explain "Created backup /etc/sshd_config at /etc/sshd_config.$bakdate.bak"

  #install pub key from github account
  style_text explain "Installing public key from EML github account"
  if [ ! -d $HOME/.ssh ]; then
    style_text explain "Making .ssh directory"
    mkdir $HOME/.ssh
  fi
  if [ ! -f $HOME/.ssh/authorized_keys ]; then
    style_text explain "Creating authorized_keys file with proper permissions."
    touch $HOME/.ssh/authorized_keys
    chmod 600 $HOME/.ssh/authorized_keys
  fi

  #check if key in file, once made or found above
  if grep -q "$publickey" $HOME/.ssh/authorized_keys ; then
    style_text warn "Public key is already installed. Skipping."
  else
    echo "$publickey" >> $HOME/.ssh/authorized_keys
  fi
}

#Do system wide defaults here
system_defaults() {
  style_text explain "Disabling Spotlight indexing for any volume that gets mounted and has not yet been indexed before."
  sudo defaults write /.Spotlight-V100/VolumeConfiguration Exclusions -array "/Volumes"

  style_text explain "Changing indexing order and disable some search results in Spotlight"
  sudo defaults write com.apple.spotlight orderedItems -array \
      '{"enabled" = 1;"name" = "APPLICATIONS";}' \
      '{"enabled" = 1;"name" = "SYSTEM_PREFS";}' \
      '{"enabled" = 1;"name" = "DIRECTORIES";}' \
      '{"enabled" = 1;"name" = "PDF";}' \
      '{"enabled" = 1;"name" = "FONTS";}' \
      '{"enabled" = 1;"name" = "DOCUMENTS";}' \
      '{"enabled" = 0;"name" = "MESSAGES";}' \
      '{"enabled" = 0;"name" = "CONTACT";}' \
      '{"enabled" = 0;"name" = "EVENT_TODO";}' \
      '{"enabled" = 1;"name" = "IMAGES";}' \
      '{"enabled" = 0;"name" = "BOOKMARKS";}' \
      '{"enabled" = 1;"name" = "MUSIC";}' \
      '{"enabled" = 1;"name" = "MOVIES";}' \
      '{"enabled" = 1;"name" = "PRESENTATIONS";}' \
      '{"enabled" = 1;"name" = "SPREADSHEETS";}' \
      '{"enabled" = 0;"name" = "MENU_OTHER";}'\
      '{"enabled" = 0;"name" = "MENU_WEBSEARCH";}' \
  # Load new settings before rebuilding the index
  killall mds > /dev/null 2>&1
  # Make sure indexing is enabled for the main volume
  sudo mdutil -i on / > /dev/null
  # Rebuild the index from scratch
  sudo mdutil -E / > /dev/null

  style_text explain "Disabling system-wide resume"
  sudo defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false

  style_text explain "Expanding the save panel by default"
  sudo defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  sudo defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  sudo defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

  style_text explain "Disabling local timemachine snapshots"
  hash tmutil &> /dev/null && sudo tmutil disablelocal

  #Expanding the save and print panel by default
  sudo defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  sudo defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  sudo defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

  #Save to disk, rather than iCloud, by default
  sudo defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

  #Enabling full keyboard access for all controls (enable Tab in modal dialogs, menu windows, etc.
  sudo defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

  #Show all filename extensions in Finder by default
  sudo defaults write NSGlobalDomain AppleShowAllExtensions -bool true
}

custom_screensaver_desktop() {
  sudo mv /System/Library/Screen\ Savers/Arabesque.qtz /System/Library/Screen\ Savers/backup.arabesque.qtz
  sudo cp ./eml_screensaver.qtz /System/Library/Screen\ Savers/
  sudo mv /System/Library/Screen\ Savers/eml_screensaver.qtz /System/Library/Screen\ Savers/Arabesque.qtz
  sudo chown root /System/Library/Screen\ Savers/Arabesque.qtz
  sudo chgrp wheel /System/Library/Screen\ Savers/Arabesque.qtz
  sudo chmod 644 /System/Library/Screen\ Savers/Arabesque.qtz

  # Set a custom wallpaper image. `DefaultDesktop.jpg` is already a symlink, and
  # all wallpapers are in `/Library/Desktop Pictures/`. The default is `Wave.jpg`.
  sudo cp ./eml_desktop.jpg /Library/Desktop\ Pictures/
  rm -rf ~/Library/Application Support/Dock/desktoppicture.db
  sudo rm -rf /System/Library/CoreServices/DefaultDesktop.jpg
  sudo ln -s /Library/Desktop\ Pictures/eml_desktop.jpg /System/Library/CoreServices/DefaultDesktop.jpg
}

configure_login_window() {
  sudo /usr/bin/defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText \
  "Welcome to the English Media Lab. Login information is available on the white board or \
  from the EML Technician. By logging in you agree to abide by the Lab Computer Guidelines. \
  Please ask the EML Technician for any assistance."
  sudo /usr/bin/defaults write /Library/Preferences/com.apple.loginwindow SHOWFULLNAME False
  sudo /usr/bin/defaults write /Library/Preferences/com.apple.loginwindow SHOWOTHERUSERS_MANAGED False
  sudo /usr/bin/defaults write /Library/Preferences/com.apple.loginwindow com.apple.login.mcx.DisableAutoLoginClient True
  #set loginwindow to use screensaver we just installed
  sudo defaults write /Library/Preferences/com.apple.screensaver loginWindowIdleTime 15
  sudo defaults write /Library/Preferences/com.apple.screensaver loginWindowModulePath "/System/Library/Screen Savers/Arabesque.qtz"
  #set PolicyBanner
  sudo cp -R ./PolicyBanner.rtfd /Library/Security/
  sudo chmod -R o+rw /Library/Security/PolicyBanner.rtfd
}

create_users() {
  #Check for highest UniqueID and for Staff GroupID for Standard Users.
  local lastid=$(/usr/bin/dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -1)
  #Staff GroupID is almost certainly 20 but why guess?
  local -ir staffgid=$(/usr/bin/dscl . -read /Groups/staff PrimaryGroupID | cut -d " " -f 2)
  #Array of EML default users (besides EML Admin)
  local -ar defusers=("Student" "Filmtech" "Instructor")
  #DON'T escape spaces in paths for dscl!
  #Admin picture is Whiterose.tif, student is Tennis.png, Filmtech is Golf.png, Instructor is 8ball.png
  local -ar userpictures=("/Library/User Pictures/Sports/Tennis.png" "/Library/User Pictures/Sports/Golf.png" "/Library/User Pictures/Sports/8ball.png")

  #createuser wants $1 USERNAME, $2 UNIQUEID, $3 USERPICTURE
  create_user() {
    local userpath=/Users/"$1"
    local username="$1"

    sudo /usr/bin/dscl . -create "$userpath"
    sudo /usr/bin/dscl . -create "$userpath" UserShell /bin/bash
    sudo /usr/bin/dscl . -create "$userpath" RealName "$username"
    sudo /usr/bin/dscl . -create "$userpath" UniqueID "$2"
    sudo /usr/bin/dscl . -create "$userpath" PrimaryGroupID "$staffgid"
    sudo /usr/bin/dscl . -create "$userpath" NFSHomeDirectory "$userpath"
    sudo /usr/bin/dscl . -create "$userpath" hint "Ask EML Technician"
    sudo /usr/bin/dscl . -create "$userpath" Picture "$3"
    sudo passwd "$1"
    sudo mkdir "$userpath"
    style_text explain "Creating ~/ at "\"$userpath\""."
    sudo cp -R /System/Library/User\ Template/English.lproj/ "$userpath"
    sudo chown -R "$1":staff "$userpath"
    style_text explain "Finished creating account "\"$1\"" at "\"$userpath\""."
  }

  #Turn off icloud set up on first login. We don't want to have to personally log into each machine to go through the intro...
  #icloud saving is dealt with in the defaults function below.
  disable_icloud_setup() {
    local user="$1"
    local userpath=/Users/"$user"
    #defaults write will make this file properly for us. No reason to check if it exists.
    sudo defaults write "$userpath"/Library/Preferences/com.apple.SetupAssistant DidSeeCloudSetup -bool TRUE
    sudo defaults write "$userpath"/Library/Preferences/com.apple.SetupAssistant GestureMovieSeen none
    sudo defaults write "$userpath"/Library/Preferences/com.apple.SetupAssistant LastSeenCloudProductVersion "${sw_vers}"
    sudo chown "$user" "$userpath"/Library/Preferences/com.apple.SetupAssistant.plist
  }

  for i in "${!defusers[@]}"
  do
    local index="$i"
    local uniqueid="$((lastid + index + 1))" #+1 to not overwrite the LASTID on the 0 index of the array.
    local username="${defusers[$i]}"
    local userpicture="${userpictures[$i]}"
    #Don't create Student and Instructor accounts if they already exist. We only check for
    #Users in standard OSX location /Users/!
    if [[ $(/usr/bin/dscl . list /Users | grep -ci "$username") -eq 0 ]]; then
      style_text explain "User "\"$username\"" does not currently exist. making "\"$username\"" account now!"
      create_user "$username" "$uniqueid" "$userpicture"
      disable_icloud_setup "$username"
      else
      style_text error "User "\"$username\"" already exists. Cannot, should not, and will not overwrite. Skipping!"
    fi
  done

}

main() {
  #Before we start. Check if we have admin privileges
  local in_admin="$(/usr/bin/dscl /Search read /Groups/admin GroupMembership | /usr/bin/grep -c $USER)"
  [ "$in_admin" != 1 ] \
  && style_text error "This script requires admin access, you're logged in as $USER!" \
  && exit 1

  intro
  read -p "Continue? [Press Enter]"

  install_homebrew_and_cask
  system_setup
  system_defaults
  custom_screensaver_desktop
  configure_login_window
  create_users

  style_text warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  style_text warn "You need to at the very least log out but should restart now."
}

main
