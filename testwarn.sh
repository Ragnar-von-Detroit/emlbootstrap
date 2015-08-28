#!/bin/env bash

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
      printf "\n${RED}${BOLD}%s\t" "EMLBOOT==>"
      printf "${UNDY}%s${RESTORE}\n" "$2"
      ;;
    warn)
      printf "\n${YELLOW}${BOLD}%s\t" "EMLBOOT==>"
      printf "${UNDY}%s${RESTORE}\n" "$2"
      ;;
    success)
      printf "\n${GREEN}${BOLD}%s\t" "EMLBOOT==>"
      printf "${UNDY}%s${RESTORE}\n" "$2"
      ;;
    highlight)
      printf "\n${BOLD}%s${RESTORE}\n" "$2"
      ;;
    explain)
      printf "\n${CYAN}%s\t" "EMLBOOT==>"
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

if [[ $(/usr/bin/grep -c "source ~/.bashrc" $HOME/.bash_profile) -eq 0 ]]; then
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
  local brew_installed=$(type brew >/dev/null 2>&1)

  check_brew_path() {
    if /usr/bin/grep -c '^export\sPATH=/usr/local/bin' ../.bashrc ); then
      style_text explain "Fixing brew path in ~/.bashrc"
      echo "$brew_path" >> $HOME/.bashrc
    else
      style_text warn "Brew path is already in .bashrc. Skiping."
    fi
  }

  if [[ brew_installed -eq 0 ]]; then
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
  #cask is a module of brew, not a full blow command, so we can't `type` it...
  local cask_installed=$(brew cask -h >/dev/null 2>&1 ; echo $?)

  # Make sure Cask symlinks to /Applications rather than ~/Applications.
  # This way we can ensure the all gui programs are accessible for all users, including our standard accounts.
  check_cask_options() {
  if [[ $(grep -c "$cask_appdir" $HOME/.bashrc) -eq 0 ]]; then
    style_text explain "Changing default Cask symlink location to /Applications in .bashrc"
    echo "$cask_appdir" >> $HOME/.bashrc
  else
    style_text warn "Cask options are already in .bashrc. Skipping."
  fi
  }

  if [[ cask_installed -eq 0 ]]; then
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

#admin level defaults. most defaults are run in a different script.
setup_system() {
  #set power and sleep schedule, set autorestart after power failure, set wake on network/modem access
  sudo /usr/bin/pmset repeat wakeorpoweron MTWRF 08:59:00 shutdown MTWRFSU 22:00:00
  sudo /usr/bin/pmset displaysleep 120 disksleep 240 sleep 480 womp 1 autorestart 1 networkoversleep 1
  sudo /usr/sbin/systemsetup -setwakeonnetworkaccess on
  #sleep security

}




intro
create_bash_profile_bashrc
install_homebrew
install_cask
