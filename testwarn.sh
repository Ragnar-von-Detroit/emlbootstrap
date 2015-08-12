#!/bin/sh

#colours for warnings


print_status() {
  RESTORE='\033[0m'

  RED='\033[00;31m'
  GREEN='\033[00;32m'
  YELLOW='\033[00;33m'
  UNDY='\033[4m'
  BOLD='\033[1m'

  case "$1" in
    error)
      echo "${RED}""${BOLD}" "==>" "${UNDY}""$2""${RESTORE}"
      ;;
    warn)
      echo "${YELLOW}""${BOLD}" "==>" "${UNDY}""$2""${RESTORE}"
      ;;
    success)
      echo "${GREEN}""${BOLD}" "==>" "${UNDY}""$2""${RESTORE}"
      ;;
    title)
      echo "${GREEN}""${BOLD}""${UNDY}""$2""${RESTORE}"
      ;;
    highlight)
      echo "${GREEN}""$2""${RESTORE}"
      ;;
    *)
      echo "print_status error. No color. What the else?"
  esac

}


  EML BOOTSTRAP INTRO

  This is the new install script for the English Media Lab.
  It will do the following tasks for you:

  1. Install xcode command line tools needed for Homebrew & Cask
  2. Install and set up Homebrew and Caskroom
  3. Set up PubkeyAuthentication in sshd_config and install SSH public key.
  4. Create Student, FilmTech, and Instructor as Standard Users. Be sure to have the standard passwords ready.
  5. Change Dock settings for all users to make it pretty the way we like it.

  This script needs to be run as EML Admin. It will make a basic minimum provision of the computer for you so that it is
  ready for Ansible management from the EML Tech machine.

  You will need to (really should) reboot after this script is finished.
