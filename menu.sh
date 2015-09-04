#!/bin/bash
OLDIFS=$IFS
IFS=$'\n'

menuExtras=$(defaults read com.apple.systemuiserver menuExtras)
menuitems=( $(echo "$menuExtras" | grep -v '[\(\)]' | sed -e 's/,//' -e 's/^ *//') )

#This needs to decrement. Since we don't update the array we don't know that...
#bluetooth has become index 0 after we removed Airport. Safer to count down.
for (( i="${#menuitems[@]}"; i>=0; i-- ))
do
  if [[ ${menuitems[$i]} =~ "AirPort" ]] ; then
    echo "${menuitems[$i]}"
    echo "Airport is menu item $i"
    # /usr/libexec/PlistBuddy -c "Delete :menuExtras:$i" $HOME/Library/Preferences/com.apple.systemuiserver.plist
  fi
  if [[ ${menuitems[$i]} =~ "Bluetooth" ]] ; then
    echo "${menuitems[$i]}"
    echo "Bluetooth is menu item $i"
    # /usr/libexec/PlistBuddy -c "Delete :menuExtras:$i" $HOME/Library/Preferences/com.apple.systemuiserver.plist
  fi
done

IFS="$OLDIFS"
