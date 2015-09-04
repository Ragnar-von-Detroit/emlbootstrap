#!/bin/bash

#colours for warnings
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
      echo "print_status error. No color. What the else?"
  esac
}

intro() {
read -d '' yell <<EOF
EML BOOTSTRAP INTRO
===================

This is the bootstrap script for the English Media Lab.

This script should be run on a fresh install only, though there are checks
in it, so nothing should be overwritten.

Here's what it does:
• Install and set up Homebrew and Homebrew Cask.
  This will trigger the install of Command Line Tools from Apple.
  You should allow this.
• Set up PubkeyAuthentication in sshd_config and install SSH public key.
  This is for the EML Account only. You'll need to su to the other accounts when
  logged in or in Ansible playbooks.
• Create Student, FilmTech, and Instructor as Standard Users.
  Be sure to have the standard passwords ready.
• Install some basic Homebrew and Cask tools that should be on each machine.
• Use dockutil (installed in the previous step) to set up docks.
• Install EML configurations for the dock and rsnapshot, controlled through
  launchd configurations. These are part of this repository.
• Set system wide defaults and program configurations.

This script needs to be run as EML Admin. It will make a basic minimum provision
of the computer for you so that it is ready for Ansible management
from the EML Tech machine.

You should reboot after this script is finished.
------------------------------------------------
EOF
style_text highlight "${yell}"
}

#Most admin tasks are performed by Ansible which does not use a login shell.
#Homebrew requires that we set its path in .bash_profile but this is only
#referenced by login shells and won't work for Anisible.
#Instead, we set the path in .bashrc and source .bashrc from .bash_profile when
#we're actually in a logged in shell. Most linux distros use this setup.
create_bash_profile_bashrc() {
  if [[ ! -f $HOME/.bashrc ]]; then
    style_text explain "Creating .bashrc for Ansible management."
    touch $HOME/.bashrc
  fi

  if grep -q "source ~/.bashrc" $HOME/.bash_profile ; then
    style_text warn "~/.bashrc already linked in ~/.bash_profile"
  else
    style_text explain "Setting .bash_profile to source .bashrc"
    cat <<EOF >> $HOME/.bash_profile
#Source .bashrc, installed by EML Bootstrap script.
#Interactive non-login for Anisible management of brew and cask.
if [ -f ~/.bashrc ]; then
   source ~/.bashrc
fi
EOF
  fi
}

install_homebrew() {
  local brew_path="export PATH=/usr/local/bin:$PATH"
  local find_brew
  find_brew=$(type brew >/dev/null 2>&1)
  brew_installed=$?

  style_text explain "Trying to install Homebrew."

  check_brew_path() {
    if grep -q '^export\sPATH=/usr/local/bin' $HOME/.bashrc ; then
      style_text error "Brew path is already in .bashrc. Skiping."
    else
      style_text explain "Fixing brew path in ~/.bashrc"
      echo "$brew_path" >> $HOME/.bashrc
    fi
  }

  if [[ "$brew_installed" -eq 0 ]]; then
    style_text warn "Brew is alread installed. Skipping installation."
    echo " "
    read -r -p "Would you like to fix the PATH in your ~/.bashrc? [Y/N] "
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      check_brew_path
    fi
  else
    style_text explain "Installing Homebrew. Follow the prompts. Requires root. You'll be asked to install Command Line Tools. Allow it."
    /usr/bin/ruby -e "$(/usr/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    check_brew_path
  fi
}

install_cask() {
  local cask_appdir="export HOMEBREW_CASK_OPTS=\"--appdir=/Applications\""
  local find_cask
  #cask is a module of brew, not a full blow command, so we can't `type` it...
  find_cask=$(brew cask -h >/dev/null 2>&1)
  cask_installed=$?

  style_text explain "Trying to install Homebrew Cask"

  # Make sure Cask symlinks to /Applications rather than ~/Applications.
  # This way we can ensure the all gui programs are accessible for all users, including our standard accounts.
  check_cask_options() {
  if grep -q "$cask_appdir" $HOME/.bashrc ; then
    style_text error "Cask options are already in .bashrc. Skipping."
  else
    style_text explain "Changing default Cask symlink location to /Applications in .bashrc"
    echo "$cask_appdir" >> $HOME/.bashrc
  fi
  }

  if [[ "$cask_installed" -eq 0 ]]; then
    style_text warn "Cask is already installed. Skipping installation."
    echo " "
    read -r -p "Would you like to set the Cask appdir option to install casks to /Applications? [Y/N]"
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      check_cask_options
    fi
  else
      style_text explain "Installing Cask. Will require root."
      /usr/local/bin/brew install caskroom/cask/brew-cask
      check_cask_options
  fi
}

system_setup() {
  declare -r bakdate=$(/bin/date -j +%d.%m.%y)
  declare -r publickey=$(curl -fSsl https://api.github.com/users/emltech/keys \
  | grep "key" \
  | cut -d " " -f 6,7 \
  | sed 's/"//g')

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
  /etc/sshd_config
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

#Do system wide defaults here. Per user defaults happen when we create user accounts
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
      '{"enabled" = 0;"name" = "DOCUMENTS";}' \
      '{"enabled" = 0;"name" = "MESSAGES";}' \
      '{"enabled" = 0;"name" = "CONTACT";}' \
      '{"enabled" = 0;"name" = "EVENT_TODO";}' \
      '{"enabled" = 0;"name" = "IMAGES";}' \
      '{"enabled" = 0;"name" = "BOOKMARKS";}' \
      '{"enabled" = 0;"name" = "MUSIC";}' \
      '{"enabled" = 0;"name" = "MOVIES";}' \
      '{"enabled" = 0;"name" = "PRESENTATIONS";}' \
      '{"enabled" = 0;"name" = "SPREADSHEETS";}' \
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
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

  #Save to disk, rather than iCloud, by default
  defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

  #Enabling full keyboard access for all controls (enable Tab in modal dialogs, menu windows, etc.
  defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

  #Show all filename extensions in Finder by default
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
}

create_users() {
  #Check for highest UniqueID and for Staff GroupID for Standard Users.
  declare -ir lastid=$(/usr/bin/dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -1)
  #Staff GroupID is almost certainly 20 but why guess?
  declare -ir staffgid=$(/usr/bin/dscl . -read /Groups/staff PrimaryGroupID | cut -d " " -f 2)
  #Array of EML default users (besides EML Admin)
  declare -ar defusers=("Student" "Filmtech" "Instructor")
  #DON'T escape spaces in paths for dscl!
  #Admin picture is Whiterose.tif, student is Golf.tif, Filmtech is Medal.tif, Instructor is Red Rose.tif
  declare -ar userpictures=("/Library/User Pictures/Sports/Golf.tif" "/Library/User Pictures/Fun/Medal.tif" "/Library/User Pictures/Flowers/Red Rose.tif")

  #createuser wants $1 USERNAME, $2 UNIQUEID, $3 USERPICTURE
  create_user() {
    local userpath=/Users/"$1"
    #Convert first letter of username to Uppercase. This is just for Real Name key, which is what shows up on login screen. (eg. Instructor)
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

  user_level_defaults() {
  		local user="$1"
  		local userpath=/Users/"$user"
  		local pref_path="$userpath/Library/Preferences"

  		###############################################################################
  		# UI
  		###############################################################################
  		#Automatically quit printer app once the print jobs complete
  		defaults write "$pref_path/"com.apple.print.PrintingPrefs "Quit When Finished" -bool true

  		# Set Help Viewer windows to non-floating mode
  		defaults write "$pref_path/"com.apple.helpviewer DevMode -bool true

  		#Disable the menubar transparency
  		defaults write "$pref_path/"com.apple.universalaccess reduceTransparency -bool true

  		# Prevent Time Machine from prompting to use new hard drives as backup volume
  		defaults write "$pref_path/"com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

  		for domain in "$pref_path/"ByHost/com.apple.systemuiserver.*; do
  			defaults write "${domain}" dontAutoLoad -array \
  				"/System/Library/CoreServices/Menu Extras/TimeMachine.menu" \
  		    "/System/Library/CoreServices/Menu Extras/Airport.menu" \
  		    "/System/Library/CoreServices/Menu Extras/Bluetooth.menu"
  		done

  		###############################################################################
  		# Finder
  		###############################################################################

  		# Show icons for hard drives, servers, and removable media on the desktop
  		defaults write "$pref_path/"com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
  		defaults write "$pref_path/"com.apple.finder ShowHardDrivesOnDesktop -bool true
  		defaults write "$pref_path/"com.apple.finder ShowMountedServersOnDesktop -bool true
  		defaults write "$pref_path/"com.apple.finder ShowRemovableMediaOnDesktop -bool true

  		#Show status bar in Finder by default
  		defaults write "$pref_path/"com.apple.finder ShowStatusBar -bool true

  		#Display full POSIX path as Finder window title
  		defaults write "$pref_path/"com.apple.finder _FXShowPosixPathInTitle -bool true

  		#Disable the warning when changing a file extension
  		defaults write "$pref_path/"com.apple.finder FXEnableExtensionChangeWarning -bool false

  		#Use list view in all Finder windows by default
  		defaults write "$pref_path/"com.apple.finder FXPreferredViewStyle -string "Nlsv"

  		# When performing a search, search the current folder by default
  		defaults write "$pref_path/"com.apple.finder FXDefaultSearchScope -string "SCcf"

  		# Automatically open a new Finder window when a volume is mounted
  		defaults write "$pref_path/"com.apple.frameworks.diskimages auto-open-ro-root -bool true
  		defaults write "$pref_path/"com.apple.frameworks.diskimages auto-open-rw-root -bool true
  		defaults write "$pref_path/"com.apple.finder OpenWindowForNewRemovableDisk -bool true

  		# Finder: disable window animations and Get Info animations
  		defaults write "$pref_path/"com.apple.finder DisableAllAnimations -bool true

  		#Avoid creation of .DS_Store files on network volumes
  		defaults write "$pref_path/"com.apple.desktopservices DSDontWriteNetworkStores -bool true

  		#Allow text selection in Quick Look/Preview in Finder by default
  		defaults write "$pref_path/"com.apple.finder QLEnableTextSelection -bool true

  		# Expand the following File Info panes:
  		# “General”, “Open with”, and “Sharing & Permissions”
  		defaults write "$pref_path/"com.apple.finder FXInfoPanesExpanded -dict \
  			General -bool true \
  			OpenWith -bool true \
  			Privileges -bool true

  		#Enable snap-to-grid for icons on the desktop and in other icon views
  		/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" "$pref_path/"Library/Preferences/com.apple.finder.plist
  		/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" "$pref_path/"Library/Preferences/com.apple.finder.plist
  		/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" "$pref_path/"Library/Preferences/com.apple.finder.plist

  		#Increase grid spacing for icons on the desktop and in other icon views
  		/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:gridSpacing 100" "$pref_path/"Library/Preferences/com.apple.finder.plist
  		/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:gridSpacing 100" "$pref_path/"Library/Preferences/com.apple.finder.plist
  		/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:gridSpacing 100" "$pref_path/"Library/Preferences/com.apple.finder.plist

  		#Increase the size of icons on the desktop and in other icon views
  		/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:iconSize 80" "$pref_path/"Library/Preferences/com.apple.finder.plist
  		/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:iconSize 80" "$pref_path/"Library/Preferences/com.apple.finder.plist
  		/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:iconSize 80" "$pref_path/"Library/Preferences/com.apple.finder.plist

  		###############################################################################
  		# Dock, Dashboard,
  		###############################################################################
  		#Most dock behaviour is controlled through Docktuil, which was installed by brew
  		#during bootstrap

  		# Enable highlight hover effect for the grid view of a stack (Dock)
  		defaults write "$pref_path/"com.apple.dock mouse-over-hilite-stack -bool true

  		# Set the icon size of Dock items to 36 pixels
  		defaults write "$pref_path/"com.apple.dock tilesize -int 36

  		# Change minimize/maximize window effect
  		defaults write "$pref_path/"com.apple.dock mineffect -string "scale"

  		# Disable Dashboard
  		defaults write "$pref_path/"com.apple.dashboard mcx-disabled -bool true

  		# Don’t show Dashboard as a Space
  		defaults write "$pref_path/"com.apple.dock dashboard-in-overlay -bool true

  		# Disable spaces and Mission Contol
  		defaults write "$pref_path/"com.apple.dock mcx-expose-disabled -bool TRUE && killall Dock

  		# Disable the Launchpad gesture (pinch with thumb and three fingers)
  		defaults write "$pref_path/"com.apple.dock showLaunchpadGestureEnabled -int 0

  		# Automatically hide and show the Dock
  		defaults write "$pref_path/"com.apple.dock autohide -bool true

  		# Hot corners
  		# Possible values:
  		#  0: no-op
  		#  2: Mission Control
  		#  3: Show application windows
  		#  4: Desktop
  		#  5: Start screen saver
  		#  6: Disable screen saver
  		#  7: Dashboard
  		# 10: Put display to sleep
  		# 11: Launchpad
  		# 12: Notification Center
  		defaults write "$pref_path/"com.apple.dock wvous-tr-corner -int 3
  		defaults write "$pref_path/"com.apple.dock wvous-tr-modifier -int 0
  		defaults write "$pref_path/"com.apple.dock wvous-tl-corner -int 4
  		defaults write "$pref_path/"com.apple.dock wvous-tl-modifier -int 0

  		defaults write "$pref_path/"com.apple.dock wvous-br-corner -int 5
  		defaults write "$pref_path/"com.apple.dock wvous-br-modifier -int 0
  		defaults write "$pref_path/"com.apple.dock wvous-bl-corner -int 10
  		defaults write "$pref_path/"com.apple.dock wvous-bl-modifier -int 0

  		###############################################################################
  		# Chrome, Safari, & WebKit
  		###############################################################################

  		#Privacy: Don’t send search queries to Apple
  		defaults write "$pref_path/"com.apple.Safari UniversalSearchEnabled -bool false
  		defaults write "$pref_path/"com.apple.Safari SuppressSearchSuggestions -bool true

  		#Hiding Safari's bookmarks bar by default
  		defaults write "$pref_path/"com.apple.Safari ShowFavoritesBar -bool false

  		#Hiding Safari's sidebar in Top Sites
  		defaults write "$pref_path/"com.apple.Safari ShowSidebarInTopSites -bool false

  		#Disabling Safari's thumbnail cache for History and Top Sites
  		defaults write "$pref_path/"com.apple.Safari DebugSnapshotsUpdatePolicy -int 2

  		#Making Safari's search banners default to Contains instead of Starts With
  		defaults write "$pref_path/"com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false

  		#Removing useless icons from Safari's bookmarks bar
  		defaults write "$pref_path/"com.apple.Safari ProxiesInBookmarksBar "()"

  		#Disabling the annoying backswipe in Chrome
  		defaults write "$pref_path/"com.google.Chrome AppleEnableSwipeNavigateWithScrolls -bool false

  		#Using the system-native print preview dialog in Chrome
  		defaults write "$pref_path/"com.google.Chrome DisablePrintPreview -bool true

  		# Expand the print dialog by default in Chrome
  		defaults write "$pref_path/"com.google.Chrome PMPrintingExpandedStateForPrint2 -bool true

  		###############################################################################
  		# Spectacle.app                                                               #
  		###############################################################################

  		defaults write "$pref_path/"com.divisiblebyzero.Spectacle MakeLarger -data 62706c6973743030d40102030405061819582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708101155246e756c6cd4090a0b0c0d0e0d0f596d6f64696669657273546e616d65576b6579436f64655624636c6173731000800280035a4d616b654c6172676572d2121314155a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21617585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11a1b54726f6f74800108111a232d32373c424b555a62696b6d6f7a7f8a939c9fa8b1c3c6cb0000000000000101000000000000001c000000000000000000000000000000cd
  		defaults write "$pref_path/"com.divisiblebyzero.Spectacle MakeSmaller -data 62706c6973743030d40102030405061819582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708101155246e756c6cd4090a0b0c0d0e0d0f596d6f64696669657273546e616d65576b6579436f64655624636c6173731000800280035b4d616b65536d616c6c6572d2121314155a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21617585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11a1b54726f6f74800108111a232d32373c424b555a62696b6d6f7b808b949da0a9b2c4c7cc0000000000000101000000000000001c000000000000000000000000000000ce
  		defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToBottomHalf -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002107d80035f10104d6f7665546f426f74746f6d48616c66d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e7072858a959ea7aab3bcced1d60000000000000101000000000000001d000000000000000000000000000000d8
  		defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToCenter -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002100880035c4d6f7665546f43656e746572d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e70727f848f98a1a4adb6c8cbd00000000000000101000000000000001d000000000000000000000000000000d2
  		defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToFullscreen -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002103180035f10104d6f7665546f46756c6c73637265656ed2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e7072858a959ea7aab3bcced1d60000000000000101000000000000001d000000000000000000000000000000d8
  		defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToLeftHalf -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002107b80035e4d6f7665546f4c65667448616c66d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e70728186919aa3a6afb8cacdd20000000000000101000000000000001d000000000000000000000000000000d4
  		defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToLowerLeft -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c617373111a008002107b80035f100f4d6f7665546f4c6f7765724c656674d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e70728489949da6a9b2bbcdd0d50000000000000101000000000000001d000000000000000000000000000000d7
  		defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToLowerRight -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c617373111a008002107d80035f10104d6f7665546f4c6f7765725269676874d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e7072858a959ea7aab3bcced1d60000000000000101000000000000001d000000000000000000000000000000d8
  		defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToNextDisplay -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731111008002107c80035f10114d6f7665546f4e657874446973706c6179d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e7072868b969fa8abb4bdcfd2d70000000000000101000000000000001d000000000000000000000000000000d9
  		defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToNextThird -data 62706c6973743030d40102030405061819582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708101155246e756c6cd4090a0b0c0d0e0d0f596d6f64696669657273546e616d65576b6579436f64655624636c6173731000800280035f100f4d6f7665546f4e6578745468697264d2121314155a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21617585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11a1b54726f6f74800108111a232d32373c424b555a62696b6d6f8186919aa3a6afb8cacdd20000000000000101000000000000001c000000000000000000000000000000d4
  		defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToPreviousDisplay -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731111008002107b80035f10154d6f7665546f50726576696f7573446973706c6179d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e70728a8f9aa3acafb8c1d3d6db0000000000000101000000000000001d000000000000000000000000000000dd
  		defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToPreviousThird -data 62706c6973743030d40102030405061819582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708101155246e756c6cd4090a0b0c0d0e0d0f596d6f64696669657273546e616d65576b6579436f64655624636c6173731000800280035f10134d6f7665546f50726576696f75735468697264d2121314155a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21617585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11a1b54726f6f74800108111a232d32373c424b555a62696b6d6f858a959ea7aab3bcced1d60000000000000101000000000000001c000000000000000000000000000000d8
  		defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToRightHalf -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002107c80035f100f4d6f7665546f526967687448616c66d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e70728489949da6a9b2bbcdd0d50000000000000101000000000000001d000000000000000000000000000000d7
  		defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToTopHalf -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002107e80035d4d6f7665546f546f7048616c66d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e707280859099a2a5aeb7c9ccd10000000000000101000000000000001d000000000000000000000000000000d3
  		defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToUpperLeft -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c617373111a008002107e80035f100f4d6f7665546f55707065724c656674d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e70728489949da6a9b2bbcdd0d50000000000000101000000000000001d000000000000000000000000000000d7
  		defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToUpperRight -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c617373111a008002107c80035f10104d6f7665546f55707065725269676874d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e7072858a959ea7aab3bcced1d60000000000000101000000000000001d000000000000000000000000000000d8
  		#run Spectacle in the background
  		defaults write "$pref_path/"com.divisiblebyzero.Spectacle StatusItemEnabled -int 0

      sudo chown "$user" "$pref_path"
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
      style_text explain "User "\"$username\"" does not currently exist. making "\"$username\"" account now!"
      create_user "$username" "$uniqueid" "$userpicture"
      disable_icloud_setup "$username"
      user_level_defaults "$username"
      else
      style_text error "User "\"$username\"" already exists. Cannot, should not, and will not overwrite. Skipping!"
    fi
  done

}


# Set a custom wallpaper image. `DefaultDesktop.jpg` is already a symlink, and
# all wallpapers are in `/Library/Desktop Pictures/`. The default is `Wave.jpg`.
#rm -rf ~/Library/Application Support/Dock/desktoppicture.db
#sudo rm -rf /System/Library/CoreServices/DefaultDesktop.jpg
#sudo ln -s /path/to/your/image /System/Library/CoreServices/DefaultDesktop.jpg

intro
create_bash_profile_bashrc
install_homebrew
install_cask
system_setup
system_defaults
create_users
