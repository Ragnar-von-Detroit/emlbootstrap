#!/bin/bash

echo "EML ADMIN BOOTSTRAP"
echo "====================="
echo "Here's what we're going to do:"
echo "Install: devtools, xcode cli, homebrew, homebrew cask (linked to /Applications)"
echo ""
echo "Set up passwordless ssh login for ansible - modify sshd_config + admin pub keys"
echo "Run Ansible playbooks for default installs. This just preps the system"
read -p "Continue [Enter]"
echo ""

declare -xi IN_ADMIN="$(/usr/bin/dscl /Search read /Groups/admin GroupMembership | /usr/bin/grep -c $USER)"
[ "$IN_ADMIN" != 1 ] &&    printf "%s\n" "This script requires admin access, you're logged in as $USER!" && exit 1

#INSTALL DEVTOOLS and CLI. From OSXC project
# Check OS to provide correct method/URL for CLI Tools installation
declare -x OSX_VERS=$(sw_vers -productVersion | awk -F "." '{print $2}')

installDevTools(){
    # Wholeheartedly lifted from
    #  https://github.com/timsutton/osx-vm-templates/blob/master/scripts/xcode-cli-tools.sh
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
declare -xa BUNDLE_IDS=('com.apple.pkg.DeveloperToolsCLI' \
    'com.apple.pkg.DeveloperToolsCLILeo' 'com.apple.pkg.CLTools_Executables' \
    'com.apple.pkg.XcodeMAS_iOSSDK_7_0')
# Set flag for the presence of a CLI tools receipt
declare -xi XCODE_CLI=0
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
    installDevTools
    if [[ $? -ne 0 ]]; then
        echo "Xcode installation failed" && exit 1
    fi
    echo ""
    echo ""
fi

#install homebrew
echo "Installing Homebrew" 
ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"

#fix brew path and make sure Cask symlinks to /Applications rather than ~/Applications.
#This way we can ensure the all gui programs are accessible for all users.
echo "Fixing Brew path"
echo "export PATH=/usr/local/bin:$PATH" >> ~/.bash_profile


#configure sshd to make it easier for remote & ansible usage, plus make it more secure
echo "Editing /etc/sshd_config: LogLevel, PermitRootLogin, PubkeyAuthentication, PasswordAuthentication"
sudo sed -i.bak \
-e 's/^#LogLevel INFO/LogLevel INFO/' \
-e 's/^#PermitRootLogin .*/PermitRootLogin no/' \
-e 's/^#PubkeyAuthentication .*/PubkeyAuthentication/' \
-e 's/^#PasswordAuthentication .*/PasswordAuthentication no/' \
/etc/sshd_config

echo "Installing public key from Github to ~/.ssh/authorized_keys"
mkdir ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
ruby -e 'require "json"; require "open-uri"; JSON.parse(open("https://api.github.com/users/emltech/keys").read).each{|x|puts x["key"]}' >> ~/.ssh/authorized_keys

echo "Creating Student and Instructor as Standard users. You'll be prompted to enter their password"

